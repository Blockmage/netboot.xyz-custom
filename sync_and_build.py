"""Sync the ISO builder workspace to a remote PVE node and execute the build."""

import os
import subprocess
import sys
from getpass import getpass

REMOTE_USER = 'root'
"""PVE node user with Docker permissions (also the user used for SSH)."""
REMOTE_HOST = 'pve3-guest1'
"""PVE node IP/Hostname (same as is configured in `~/.ssh` where the this script is being executed)."""
REMOTE_PATH = '/tmp/iso-builder'
"""Directory on the PVE node in which to host the build files."""
ISO_FILE_NAME = 'rescue-deb-amd64.iso'
"""Name of the resulting ISO file."""
RSYNC_EXCLUDE_FILE = 'rsync-exclude.txt'
"""Path of the rsync exclusions file."""


def print_log(*s: str) -> None:
    """Print a log message to standard error."""
    print(*s, file=sys.stderr)


def run_remote_command(command: str) -> None:
    """Execute a command on the remote host via SSH."""
    ssh_cmd = ['ssh', f'{REMOTE_USER}@{REMOTE_HOST}', command]
    subprocess.run(ssh_cmd, check=True)


def sync_workspace() -> None:
    """Sync the local directory to the remote host, excluding output."""
    print_log(f'--- Syncing workspace to {REMOTE_HOST}')
    rsync_cmd = [
        'rsync',
        '-avz',
        '--delete',
        '--exclude-from',
        f'{RSYNC_EXCLUDE_FILE}',
        './',
        f'{REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}',
    ]
    subprocess.run(rsync_cmd, check=True)


def build_iso_remotely(root_pass: str, ssh_key: str) -> None:
    """Trigger the Docker build on the remote PVE node."""
    print_log('--- Starting Docker build on remote')
    docker_cmd = (
        f'cd {REMOTE_PATH} && '
        f'docker build -t iso-builder . && '
        f'mkdir -p {REMOTE_PATH}/output && '
        f'docker run --rm --privileged '
        f'-v {REMOTE_PATH}/output:/output '
        f"-e ROOT_PASS='{root_pass}' "
        f"-e SSH_KEY='{ssh_key}' "
        f'iso-builder'
    )
    run_remote_command(docker_cmd)


def fetch_iso() -> None:
    """Pull the finished ISO back to the local output directory."""
    print_log('--- Fetching built ISO')
    os.makedirs('./output', exist_ok=True)
    scp_cmd = [
        'scp',
        f'{REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/output/{ISO_FILE_NAME}',
        f'./output/{ISO_FILE_NAME}',
    ]
    subprocess.run(scp_cmd, check=True)


def main() -> None:
    if not (ssh_key := os.getenv('SSH_PUBKEY', '').strip()):
        ssh_key = input('Paste SSH Public Key: ').strip()
    if not (root_pass := os.getenv('ROOT_PASS', '').strip()):
        root_pass = getpass('Enter Root Password for ISO: ')
    try:
        sync_workspace()
        build_iso_remotely(root_pass, ssh_key)
        fetch_iso()
        print_log(f"\n--- Success: ISO is located in './output/{ISO_FILE_NAME}'")
    except subprocess.CalledProcessError as err:
        redacted_err = str(err).replace(root_pass, '***')
        str_div = '\n' + ('-' * 80) + '\n'
        print_log(f'\n--- Build failed:{str_div}{redacted_err}{str_div}')


if __name__ == '__main__':
    main()

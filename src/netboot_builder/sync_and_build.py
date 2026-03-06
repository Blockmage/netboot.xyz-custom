import os
import subprocess
import sys
from getpass import getpass

from dotenv import load_dotenv

from .config import Config

load_dotenv()
cfg = Config()


def print_log(*s: str) -> None:
    """Print a log message to standard error."""
    print(*s, file=sys.stderr)


def run_remote_command(command: str) -> None:
    """Execute a command on the remote host via SSH."""
    ssh_cmd = ['ssh', f'{cfg.remote_user}@{cfg.remote_host}', command]
    subprocess.run(ssh_cmd, check=True)


def sync_workspace() -> None:
    """Sync the local directory to the remote host, excluding output."""
    print_log(f'--- Syncing workspace to {cfg.remote_host}')
    rsync_cmd = [
        'rsync',
        '-avz',
        '--delete',
        '--exclude-from',
        f'{cfg.rsync_exclude_file}',
        './',
        f'{cfg.remote_user}@{cfg.remote_host}:{cfg.remote_path}',
    ]
    subprocess.run(rsync_cmd, check=True)


def build_iso_remotely(root_pass: str, ssh_key: str) -> None:
    """Trigger the Docker build on the remote PVE node."""
    print_log('--- Starting Docker build on remote')
    docker_cmd = (
        f'cd {cfg.remote_path} && '
        f'docker build -t iso-builder . && '
        f'mkdir -p {cfg.remote_path}/output && '
        f'docker run --rm --privileged '
        f'-v {cfg.remote_path}/output:/output '
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
        f'{cfg.remote_user}@{cfg.remote_host}:{cfg.remote_path}/output/{cfg.iso_file_name}',
        f'./output/{cfg.iso_file_name}',
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
        print_log(f"\n--- Success: ISO is located in './output/{cfg.iso_file_name}'")
    except subprocess.CalledProcessError as err:
        redacted_err = str(err).replace(root_pass, '***')
        str_div = '\n' + ('-' * 80) + '\n'
        print_log(f'\n--- Build failed:{str_div}{redacted_err}{str_div}')


if __name__ == '__main__':
    main()

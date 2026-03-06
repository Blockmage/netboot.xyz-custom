import os
import subprocess
import sys
from functools import lru_cache
from getpass import getpass

from dotenv import load_dotenv

from .config import Config

load_dotenv()


@lru_cache(maxsize=1)
def _get_cfg() -> Config:
    return Config.from_file()


def print_log(*s: str) -> None:
    """Print a log message to standard error."""
    print(*s, file=sys.stderr)


def run_remote_command(command: str) -> None:
    """Execute a command on the remote host via SSH."""
    _cfg = _get_cfg()
    ssh_cmd = ['ssh', f'{_cfg.remote_user}@{_cfg.remote_host}', command]
    subprocess.run(ssh_cmd, check=True)


def sync_workspace(*, remove_remote_files: bool = False) -> None:
    """Sync the local directory to the remote host, excluding output."""
    _cfg = _get_cfg()
    if remove_remote_files:
        print_log(f"--- Removing files in remote directory '{_cfg.remote_path}'")
        run_remote_command(f'rm -rf {_cfg.remote_path}')

    print_log(f'--- Syncing workspace to {_cfg.remote_host}')
    rsync_cmd = [
        'rsync',
        '-avz',
        '--delete',
        '--exclude-from',
        f'{_cfg.rsync_exclude_file}',
        './',
        f'{_cfg.remote_user}@{_cfg.remote_host}:{_cfg.remote_path}',
    ]
    subprocess.run(rsync_cmd, check=True)


def build_iso_remotely(root_pass: str, ssh_key: str) -> None:
    """Trigger the Docker build on the remote PVE node."""
    _cfg = _get_cfg()
    print_log('--- Starting Docker build on remote')
    docker_cmd = (
        f'cd {_cfg.remote_path} && '
        f'docker build -t iso-builder . && '
        f'mkdir -p {_cfg.remote_path}/output && '
        f'docker run --rm --privileged '
        f'-v {_cfg.remote_path}/output:/output '
        f"-e ROOT_PASS='{root_pass}' "
        f"-e SSH_KEY='{ssh_key}' "
        f'iso-builder'
    )
    run_remote_command(docker_cmd)


def fetch_iso() -> None:
    """Pull the finished ISO back to the local output directory."""
    _cfg = _get_cfg()
    print_log('--- Fetching built ISO')
    os.makedirs('./output', exist_ok=True)
    scp_cmd = [
        'scp',
        f'{_cfg.remote_user}@{_cfg.remote_host}:{_cfg.remote_path}/output/{_cfg.iso_file_name}',
        f'./output/{_cfg.iso_file_name}',
    ]
    subprocess.run(scp_cmd, check=True)


def main() -> None:
    _cfg = _get_cfg()
    if not ((ssh_key := os.getenv('SSH_PUBKEY', '').strip()) and not (ssh_key := _cfg.ssh_pubkey)):
        ssh_key = input('Paste SSH Public Key: ').strip()
    if not ((root_pass := os.getenv('ROOT_PASS', '').strip()) and not (root_pass := _cfg.root_pass)):
        root_pass = getpass('Enter Root Password for ISO: ')
    try:
        sync_workspace(remove_remote_files=_cfg.cleanup_build_directory)
        build_iso_remotely(root_pass, ssh_key)
        fetch_iso()
        print_log(f"\n--- Success: ISO is located in './output/{_cfg.iso_file_name}'")
    except subprocess.CalledProcessError as err:
        redacted_err = str(err).replace(root_pass, '***')
        str_div = '\n' + ('-' * 80) + '\n'
        print_log(f'\n--- Build failed:{str_div}{redacted_err}{str_div}')


if __name__ == '__main__':
    main()

from __future__ import annotations

import asyncio
import os
from pathlib import Path
from typing import TYPE_CHECKING, Any, ClassVar, Final, TypeGuard

from msgspec import field, json, toml, yaml
from msgspec.structs import Struct, fields

if TYPE_CHECKING:
    from onepassword import Client as ClientT


type PathLike = Path | str

if _workspace_root := os.getenv('WORKSPACE_ROOT', '').strip():
    _workspace_root = Path(_workspace_root)
else:
    _workspace_root = Path(__file__).parents[2]

WORKSPACE_ROOT: Final[Path] = _workspace_root


def _is_pathlike(s: object, /) -> TypeGuard[PathLike]:
    return hasattr(s, '__fspath__') or isinstance(s, str)


def _deserialize_pathlike(_: type, obj: Any) -> Path | None:
    if _is_pathlike(obj):
        return Path(obj)
    raise NotImplementedError


class BaseConfig(Struct, kw_only=True):
    _op_client: ClassVar[Any | None] = None
    _op_integration_name: ClassVar[Final[str]] = 'netboot-builder'
    _op_integration_version: ClassVar[Final[str]] = 'v1.0.0'

    workspace_root: ClassVar[Path] = WORKSPACE_ROOT
    config_file_path: ClassVar[Path] = WORKSPACE_ROOT / 'config.yml'

    op_account: str = field(default_factory=lambda: os.getenv('OP_ACCOUNT', ''))
    """Name of the 1Password account (if using the 1Password desktop app integration) (environment: `'OP_ACCOUNT'`)."""

    op_service_account_token: str = field(default_factory=lambda: os.getenv('OP_SERVICE_ACCOUNT_TOKEN', ''))
    """1Password service account token (if using a service account) (environment: `'OP_SERVICE_ACCOUNT_TOKEN'`)."""

    def __post_init__(self) -> None:
        asyncio.run(self._resolve_secret_fields())

    @classmethod
    def from_file(cls, *, path: PathLike | None = None) -> Config:
        if path is None and cls.config_file_path.exists():
            path = cls.config_file_path
        if path is not None:
            path, kwds = Path(path), {'type': Config, 'dec_hook': _deserialize_pathlike}
            if (suf := path.suffix) in ('.yaml', '.yml'):
                return yaml.decode(path.read_bytes(), **kwds)
            if suf == '.toml':
                return toml.decode(path.read_bytes(), **kwds)
            if suf == '.json':
                return json.decode(path.read_bytes(), **kwds)
            msg = f"File extension must be one of '.yaml', '.yml', '.toml', or '.json' - Received: {suf}"
        else:
            msg = f'File path is missing or file does not exist: {path}'
        raise ValueError(msg)

    @classmethod
    async def _get_op_client(cls, *, acc_name: str = '', tkn: str = '') -> ClientT:
        if cls._op_client is None:
            try:
                from onepassword import Client, DesktopAuth
            except ImportError as err:
                msg = "Missing required dependency 'onepassword-sdk'"
                raise ImportError(msg) from err
            else:
                tkn, acc_name, client = '', '', None
                kwds = {
                    'integration_name': cls._op_integration_name,
                    'integration_version': cls._op_integration_version,
                }
                if not acc_name.strip() and (acc_name := os.getenv('OP_ACCOUNT', '').strip()):
                    client = await Client.authenticate(auth=DesktopAuth(account_name=acc_name), **kwds)
                if not tkn.strip() and (tkn := os.getenv('OP_SERVICE_ACCOUNT_TOKEN', '').strip()):
                    client = await Client.authenticate(auth=tkn, **kwds)
                if (not tkn.strip() and not acc_name.strip()) or client is None:
                    msg = "If using 1Password, at least one of 'OP_ACCOUNT' or 'OP_SERVICE_ACCOUNT_NAME' "
                    msg += 'variables must be set and non-empty in the environment'
                    raise ValueError(msg)
                cls._op_client = client
                return cls._op_client
        else:
            return cls._op_client

    async def _resolve_secret_fields(self) -> None:
        if secret_refs := {
            fld.name: fld_val
            for fld in fields(self)
            if fld.type is str and (fld_val := str(getattr(self, fld.name)).strip()) and fld_val.startswith('op://')
        }:
            client = await self._get_op_client(acc_name=self.op_account, tkn=self.op_service_account_token)
            secrets = await client.secrets.resolve_all(list(secret_refs.values()))
            for attr_name, resolved_value in zip(
                secret_refs.keys(), secrets.individual_responses.values(), strict=False
            ):
                if (res := resolved_value.content) is not None and res.secret:
                    setattr(self, attr_name, str(res.secret))


class Config(BaseConfig, kw_only=True):
    name: str = ''
    """Optional name for the configuration."""

    root_pass: str = ''
    """Password for the root user in the built image."""

    ssh_pubkey: str = ''
    """SSH public key for the root user in the built image."""

    remote_user: str = 'root'
    """Remote user with Docker permissions (also the user used for SSH)."""

    remote_host: str = 'pve3-guest1'
    """Remote hostname/IP (same as is configured in `~/.ssh` on the machine where this script is being executed)."""

    remote_path: str = '/tmp/iso-builder'
    """Directory on the remote in which to host the build files."""

    iso_file_name: str = 'rescue-deb-amd64.iso'
    """Name of the resulting ISO file."""

    rsync_exclude_file: Path = WORKSPACE_ROOT / 'rsync-exclude.txt'
    """Path of the rsync exclusions file."""

    cleanup_build_directory: bool = False
    """Whether to remove the files in the remote build directory before syncing the workspace."""


if __name__ == '__main__':
    from devtools import debug
    from dotenv import load_dotenv
    from msgspec.structs import asdict

    print(f'{load_dotenv()=}')
    print(f'{WORKSPACE_ROOT=}')
    print(f'{WORKSPACE_ROOT.exists()=}')

    cfg = Config.from_file()
    debug(asdict(cfg))

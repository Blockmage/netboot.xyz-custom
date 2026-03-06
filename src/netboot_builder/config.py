from __future__ import annotations

import asyncio
import os
from pathlib import Path
from typing import TYPE_CHECKING, Any, ClassVar, Final, TypeGuard

from msgspec import json, toml, yaml
from msgspec.structs import Struct, fields

if TYPE_CHECKING:
    from onepassword import Client as ClientT


type PathLike = Path | str


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

    def __post_init__(self) -> None:
        asyncio.run(self._resolve_secret_fields())

    @classmethod
    def from_file(cls, path: PathLike) -> Config:
        path = Path(path)
        if (suf := path.suffix) in ('.yaml', '.yml'):
            return yaml.decode(path.read_bytes(), type=Config, dec_hook=_deserialize_pathlike)
        if suf == '.toml':
            return toml.decode(path.read_bytes(), type=Config, dec_hook=_deserialize_pathlike)
        if suf == '.json':
            return json.decode(path.read_bytes(), type=Config, dec_hook=_deserialize_pathlike)
        msg = f"File extension must be one of '.yaml', '.yml', '.toml', or '.json' - Received: {suf}"
        raise ValueError(msg)

    @classmethod
    async def _get_op_client(cls) -> ClientT:
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
                if acc_name := os.getenv('OP_ACCOUNT', '').strip():
                    client = await Client.authenticate(auth=DesktopAuth(account_name=acc_name), **kwds)
                if tkn := os.getenv('OP_SERVICE_ACCOUNT_TOKEN', '').strip():
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
            for fld in [fld for fld in fields(self) if fld.type is str]
            if (fld_val := str(getattr(self, fld.name)).strip()) and fld_val.startswith('op://')
        }:
            client = await self._get_op_client()
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

    rsync_exclude_file: Path = Path('rsync-exclude.txt')
    """Path of the rsync exclusions file."""

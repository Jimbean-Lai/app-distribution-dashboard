"""适配器注册表：平台名 -> 适配器类（按需惰性加载）。

惰性加载保证不安装 Google API 依赖也能使用 CLI 的 platforms / validate 等命令。
"""
from __future__ import annotations

import importlib
from typing import Any, Dict, List, Type

from .base import StoreAdapter, StoreError
from .models import Platform

_PLATFORM_MODULES = {
    Platform.HUAWEI.value: "app_store.stores.huawei",
    Platform.OPPO.value: "app_store.stores.oppo",
    Platform.VIVO.value: "app_store.stores.vivo",
    Platform.XIAOMI.value: "app_store.stores.xiaomi",
    Platform.HONOR.value: "app_store.stores.honor",
    Platform.GOOGLE.value: "app_store.stores.google",
    Platform.APPLE.value: "app_store.stores.apple",
    Platform.QQ.value: "app_store.stores.qq",
}

_REGISTRY: Dict[str, Type[StoreAdapter]] = {}
# 平台适配器模块加载失败的非依赖原因（ImportError 属可选依赖缺失，静默跳过）
_LOAD_ERRORS: Dict[str, str] = {}


def _load_all() -> None:
    for key, module in _PLATFORM_MODULES.items():
        if key in _REGISTRY:
            continue
        try:
            mod = importlib.import_module(module)
        except ImportError:
            # 可选依赖未安装（如 google-api-python-client），静默跳过
            continue
        except Exception as e:
            # 模块自身代码错误等，记录真实原因以便排查
            _LOAD_ERRORS[key] = f"{type(e).__name__}: {e}"
            continue
        for obj in vars(mod).values():
            if (
                isinstance(obj, type)
                and issubclass(obj, StoreAdapter)
                and obj is not StoreAdapter
                and getattr(obj, "platform", None) is not None
                and obj.platform.value == key
            ):
                _REGISTRY[key] = obj


def get_adapter(platform: object, credentials: Dict[str, Any]) -> StoreAdapter:
    _load_all()
    key = platform.value if isinstance(platform, Platform) else str(platform).lower()
    cls = _REGISTRY.get(key)
    if cls is None:
        reason = _LOAD_ERRORS.get(key)
        msg = f"平台未注册或加载失败: {key}"
        if reason:
            msg += f"（{reason}）"
        raise StoreError(msg)
    return cls(credentials.get(key) or {})


def list_platforms() -> List[Dict[str, Any]]:
    _load_all()
    items: List[Dict[str, Any]] = []
    for p in Platform:
        cls = _REGISTRY.get(p.value)
        if cls is None:
            continue
        items.append(
            {
                "platform": p.value,
                "display_name": getattr(cls, "display_name", None) or p.display_name,
                "availability": getattr(cls, "availability", "ready"),
                "credential_fields": list(getattr(cls, "required_credential_fields", ())),
            }
        )
    return items

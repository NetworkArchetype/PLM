from typing import Any, Dict, List, overload, TypeVar

import duet


T = TypeVar('T')


@overload
async def foo_async(x: int) -> int:
    ...


@overload
async def foo_async(x: str) -> str:
    ...


@overload
async def foo_async(x: List[T]) -> List[T]:
    ...


async def foo_async(x: Any) -> Any:
    return x * 2


foo = duet.sync(foo_async)


class Bar:
    async def baz_async(self, x: int, *, y: str) -> Dict[int, str]:
        return {}

    baz = duet.sync(baz_async)


b = Bar()

reveal_type(duet.sync)

reveal_type(foo_async)
reveal_type(foo)

reveal_type(Bar.baz_async)
reveal_type(Bar.baz)

reveal_type(b.baz_async)
reveal_type(b.baz)

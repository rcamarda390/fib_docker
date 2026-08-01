import pathlib

matches = list(pathlib.Path("/install/lib").glob("python*/site-packages/gnosis_mcp/rest.py"))
assert len(matches) == 1, f"PATCH FAILED: expected one rest.py, found {len(matches)}"
path = matches[0]
src = path.read_text()

old = '    app = Starlette(routes=routes, lifespan=_make_lifespan(config))'
new = (
    '    import contextlib as _contextlib\n'
    '    _rest_lifespan = _make_lifespan(config)\n'
    '    @_contextlib.asynccontextmanager\n'
    '    async def _combined_lifespan(app):\n'
    '        async with _contextlib.AsyncExitStack() as _stack:\n'
    '            _state = await _stack.enter_async_context(_rest_lifespan(app))\n'
    '            if transport != "sse":\n'
    '                await _stack.enter_async_context(mcp_server.session_manager.run())\n'
    '            yield _state\n'
    '    app = Starlette(routes=routes, lifespan=_combined_lifespan)'
)

assert old in src, "PATCH FAILED: target line not found in rest.py"
patched = src.replace(old, new, 1)
path.write_text(patched)
print("rest.py patched successfully")

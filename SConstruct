# Starter SConstruct for enscons

import enscons
import setuptools_scm
import pytoml

from clvm_tools_rs import compile_clvm


metadata = dict(pytoml.load(open("pyproject.toml")))["tool"]["enscons"]
metadata["version"] = setuptools_scm.get_version(local_scheme="no-local-version")

full_tag = "py3-none-any"  # pure Python packages compatible with 2+3


def build_cl(target, source, env):
    assert len(source) == 1
    assert len(target) == 1
    rv = compile_clvm(
        str(source[0]),
        str(target[0]),
        search_paths=env.get("CL_INCLUDE", "")
    )

cl_builder = Builder(action = build_cl, suffix=".cl.hex")

env = Environment(
    tools=["default", "packaging", enscons.generate],
    PACKAGE_METADATA=metadata,
    WHEEL_TAG=full_tag,
    ROOT_IS_PURELIB=full_tag.endswith("-any"),
)
env["BUILDERS"]["Chialisp"] = cl_builder
env["CL_INCLUDE"] = ["clvm_contracts/include"]

for cl in "allow_everything.cl composite_amount_validation.cl rate_limit_validation.cl validating_meta_puzzle.cl".split():
    env.Chialisp(f"clvm_contracts/{cl}")

# Only *.py is included automatically by setup2toml.
# Add extra 'purelib' files or package_data here.
py_source = (
    Glob("clvm_contracts/*.py")
    + Glob("clvm_contracts/*/*.py")
    + Glob("clvm_contracts/puzzles/*cl")
    + Glob("clvm_contracts/puzzles/*clvm")
)

source = env.Whl("purelib", py_source, root="")
whl = env.WhlFile(source=source)

# It's easier to just use Glob() instead of FindSourceFiles() since we have
# so few installed files..
sdist_source = (
    File(["PKG-INFO", "README.md", "SConstruct", "pyproject.toml"]) + py_source
)
sdist = env.SDist(source=sdist_source)
env.NoClean(sdist)
env.Alias("sdist", sdist)

# needed for pep517 (enscons.api) to work
env.Default(whl, sdist)

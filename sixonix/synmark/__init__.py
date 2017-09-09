from .run import run
from .. import install as _install

BENCHMARKS = [
    "OglBatch0",
    "OglBatch1",
    "OglBatch2",
    "OglBatch3",
    "OglBatch4",
    "OglBatch5",
    "OglBatch6",
    "OglBatch7",
    "OglCSCloth",
    "OglCSDof",
    "OglDeferred",
    "OglDeferredAA",
    "OglDrvRes",
    "OglDrvShComp",
    "OglDrvState",
    "OglFillPixel",
    "OglFillTexMulti",
    "OglFillTexSingle",
    "OglGeomPoint",
    "OglGeomTriList",
    "OglGeomTriStrip",
    "OglHdrBloom",
    "OglMultithread",
    "OglPSBump2",
    "OglPSBump8",
    "OglPSPhong",
    "OglPSPom",
    "OglShMapPcf",
    "OglShMapVsm",
    "OglTerrainFlyInst",
    "OglTerrainFlyTess",
    "OglTerrainPanInst",
    "OglTerrainPanTess",
    "OglTexFilterAniso",
    "OglTexFilterTri",
    "OglTexMem128",
    "OglTexMem512",
    "OglVSDiffuse1",
    "OglVSDiffuse8",
    "OglVSInstancing",
    "OglVSTangent",
    "OglZBuffer",
]

def install():
    _install.install_benchmarks_for_module("synmark")

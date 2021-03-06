
type
  Impl* {.pure.} = enum
    Standard, Arraymancer

  ImplFeature* {.pure.} = enum
    OpenMP, Simd

proc getImpl*(): Impl =
  when defined(arraymancer):
    Impl.Arraymancer
  else:
    Impl.Standard

proc getImplFeatures*(): set[ImplFeature] =
  result = {}
  when defined(openmp):
    result.incl(ImplFeature.OpenMP)
  when defined(simd):
    result.incl(ImplFeature.Simd)

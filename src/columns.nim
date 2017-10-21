import future
import sequtils
import strutils
import typetraits
import macros

type
  Column* = ref object of RootObj

  TypedCol*[T] = ref object of Column
    arr*: seq[T]

method `$`*(c: Column): string {.base.} =
  raise newException(AssertionError, "`$` of base method should not be called.")

method `$`*[T](c: TypedCol[T]): string =
  let typeName = name(T)
  result = "TypedCol[" & typeName & "](" & $c.arr & ")"

method `typeName`*(c: Column): string {.base.} =
  raise newException(AssertionError, "`typeName` of base method should not be called.")

method `typeName`*[T](c: TypedCol[T]): string =
  result = name(T)

method `len`*(c: Column): int {.base.} =
  raise newException(AssertionError, "`len` of base method should not be called.")

method `len`*[T](c: TypedCol[T]): int =
  result = c.arr.len


proc newCol*[T](s: seq[T]): Column =
  return TypedCol[T](arr: s)

proc newCol*[T](length: int): Column =
  return TypedCol[T](arr: newSeq[T](length))


template assertType(c: Column, T: typedesc): TypedCol[T] =
  if not (c of TypedCol[T]):
    let pos = instantiationInfo()
    let msg = "Expected column of type [$1], got [$2] at $3:$4" % [
      name(T),
      c.typeName(),
      pos.filename,
      $pos.line,
    ]
    echo msg
    raise newException(ValueError, msg)
  cast[TypedCol[T]](c)

template toTyped(newCol: untyped, c: Column, T: typedesc): untyped =
  ## Alternative to assertType.
  ## Pro: - The user doesn't have to decide between let or var.
  ## Con: - Doesn't emphasize that there is an assertion.
  if not (c of TypedCol[T]):
    raise newException(ValueError, "Expected column of type " & name(T))
  let newCol = cast[TypedCol[T]](c)


macro multiImpl(c: Column, cTyped: untyped, types: untyped, procBody: untyped): untyped =
  echo c.treeRepr
  echo types.treeRepr
  echo procBody.treeRepr
  result = newIfStmt()
  for t in types:
    echo t.treeRepr
    let elifBranch = newNimNode(nnkElifBranch)
    let cond = infix(c, "of", newNimNode(nnkBracketExpr).add(bindSym"TypedCol", t))
    let body = newStmtList()
    body.add(newLetStmt(cTyped, newCall(bindSym"assertType", c, t)))
    body.add(procBody)
    elifBranch.add(cond)
    elifBranch.add(body)
    result.add(elifBranch)
  result = newStmtList(result)
  echo result.repr

template defaultImpls(c: Column, cTyped: untyped, procBody: untyped): untyped =
  if c of TypedCol[int16]:
    let `cTyped` {.inject.} = c.assertType(int16)
    procBody
  elif c of TypedCol[int32]:
    let `cTyped` {.inject.} = c.assertType(int32)
    procBody
  elif c of TypedCol[int64]:
    let `cTyped` {.inject.} = c.assertType(int64)
    procBody
  elif c of TypedCol[float32]:
    let `cTyped` {.inject.} = c.assertType(float32)
    procBody
  elif c of TypedCol[float64]:
    let `cTyped` {.inject.} = c.assertType(float64)
    procBody

proc sum*[T](c: TypedCol[T]): float =
  var sum = 0.0
  for x in c.arr:
    sum += x.float
  return sum

proc sumExplicit*(c: Column): float =
  if c of TypedCol[int]:
    let cTyped = c.assertType(int)
    return cTyped.sum()
  elif c of TypedCol[float32]:
    let cTyped = c.assertType(float32)
    return cTyped.sum()
  elif c of TypedCol[float64]:
    let cTyped = c.assertType(float64)
    return cTyped.sum()
  else:
    raise newException(ValueError, "sum not implemented for type: " & c.typeName())

#[
proc sum*(c: Column): float =
  multiImpl(c, cTyped, [int, float32]):#, float32, float64]):
    return cTyped.sum()
]#

proc sum*(c: Column): float =
  defaultImpls(c, cTyped):
    return cTyped.sum()


proc mean*(c: Column): float =
  c.sum / c.len.float


when isMainModule:
  proc genDynamicCol(s: string): Column =
    case s
    of "string":
      return newCol(@["1", "2", "3"])
    of "int":
      return newCol(@[1, 2, 3])

  proc operateOnCol(c: Column) =
    if c of TypedCol[string]:
      let cTyped = cast[TypedCol[string]](c)
      echo "string column": cTyped.arr
    elif c of TypedCol[int]:
      let cTyped = cast[TypedCol[int]](c)
      echo "int column": cTyped.arr
    else:
      echo "can't match type"

  let c1 = genDynamicCol("string")
  let c2 = genDynamicCol("int")

  echo c1
  echo c2
  operateOnCol(c1)
  operateOnCol(c2)

  block:  # block allows to re-use variable names
    let c1 = c1.assertType(string)
    let c2 = c2.assertType(int)
    echo c1.arr
    echo c2.arr

  block:  # block allows to re-use variable names
    toTyped(c1, c1, string)
    toTyped(c2, c2, int)
    echo c1.arr
    echo c2.arr
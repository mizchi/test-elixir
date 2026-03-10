(module
  (func $add (export "add") (param $left i32) (param $right i32) (result i32)
    local.get $left
    local.get $right
    i32.add)

  (func $fib (export "fib") (param $n i32) (result i32)
    local.get $n
    i32.const 2
    i32.lt_s
    if (result i32)
      local.get $n
    else
      local.get $n
      i32.const 1
      i32.sub
      call $fib
      local.get $n
      i32.const 2
      i32.sub
      call $fib
      i32.add
    end))

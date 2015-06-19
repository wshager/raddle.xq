xquery version "3.1";

import module namespace raddle="http://lagua.nl/lib/raddle" at "lib/raddle.xql";

let $value := raddle:parse("use(core/aggregate-functions,core/string-regex-functions),define(depth,(string),number,(tokenize(.,/),count(.))),local:depth(.)")
let $params := map { "raddled" := "/db/apps/raddle-tests/raddled", "dict" := map {} }
let $dict := raddle:process($value,$params)
let $func := raddle:eval($dict,$params)
return $func("/db/s/f")
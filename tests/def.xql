xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace raddle="http://lagua.nl/lib/raddle" at "lib/raddle.xql";

let $value := raddle:parse("use(core/aggregate-functions,core/string-regex-functions),define(depth,(string),number,(tokenize(.,/),count(.))),local:depth(.)")
let $params := map { "raddled" := "/db/apps/raddle-tests/raddled", "dict" := map {} }
let $dict := raddle:process($value,$params)
return serialize($dict,
<output:serialization-parameters>
    <output:method>json</output:method>
</output:serialization-parameters>)
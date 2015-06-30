xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

let $value := raddle:parse("use(op/numeric-arithmetic-operators,op/numeric-comparison-operators,hof/unfold-functions),hof:unfold(.,(op:add(.,1)),(op:greater-than(.,10)),new:array())")
let $params := map { "raddled" := "/db/apps/raddled", "dict" := map {} }
let $dict := raddle:process($value,$params)
return serialize($dict,
<output:serialization-parameters>
    <output:method>json</output:method>
</output:serialization-parameters>)
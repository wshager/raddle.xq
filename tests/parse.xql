xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$transpile":="js"}

let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/core.rdl"), "utf-8")
let $parsed := raddle:parse($query,$params)
return serialize($parsed,
<output:serialization-parameters>
    <output:method>json</output:method>
</output:serialization-parameters>)
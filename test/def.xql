xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace raddle="http://lagua.nl/lib/raddle" at "lib/raddle.xql";

declare function local:use($value,$params){
    let $mods := $value("args")
    let $map := doc($params("raddled") || "/map.xml")/root/module
    let $main := distinct-values(array:for-each($mods,function($_){
        tokenize($_,"/")[1]
    }))
    let $reqs := for-each($main,function($_){
        let $uri := xs:anyURI($map[@rdl = $_]/@xq)
        let $module := inspect:inspect-module-uri($uri)
        return try {
            util:import-module(xs:anyURI($module/@uri), $module/@prefix, xs:anyURI($module/@location))
        } catch * {
            ()
        }
    })
    let $dict := $params("dict")
    return array:fold-left($mods,$dict,function($acc,$_){
        let $src := util:binary-to-string(util:binary-doc($params("raddled") || "/" || $_ || ".rdl"))
        let $parsed := raddle:parse($src)
        let $defs := raddle:process($parsed,map:new(($params,map {"use" := $_})))
        return map:new(($acc,$defs))
    })
};

let $parsed := raddle:parse("use(core/aggregate-functions,core/string-regex-functions)")
let $def := raddle:use($parsed(1),map { "raddled" := "/db/data/raddled", "dict" := map {} })
return serialize($def,
<output:serialization-parameters>
    <output:method>json</output:method>
</output:serialization-parameters>)
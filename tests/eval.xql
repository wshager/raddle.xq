xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare option output:method "json";
declare option output:media-type "application/json";

let $compat := request:get-parameter("compat","xquery")
let $transpile := request:get-parameter("transpile","l3")
let $query := util:binary-to-string(request:get-data())
return xqc:normalize-query($query,map { "$compat": $compat, "$transpile": $transpile })
(:return xqc:analyze-chars(xqc:to-buffer($query),true()):)


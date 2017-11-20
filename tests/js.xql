xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$transpile":="js"}

let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/raddle.rdl"), "utf-8")

(:let $query  := 'core:item($,closes,core:filter(subsequence($lastseen,$lastindex,count($lastseen)),(core:geq(.,(2.08,2.11))))),core:item($,closes,($closes,2.11))':)

(:return raddle:exec($query,$params):)

return xmldb:store("/db/apps/raddle.xq/js","raddle.js",raddle:exec($query,$params),"application/javascript")
xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$compat" := "xquery", "$transpile":="js"}

let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/lib/core.xql"), "utf-8")

let $module := raddle:exec($query,$params)
return $module

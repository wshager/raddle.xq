xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {},"modules" := "/db/apps/raddle.xq/content/modules.xml"}

let $doc := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/raddle.rdl"))

return raddle:transpile($doc,$params)

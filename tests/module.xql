xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {},"modules" := "/db/apps/raddle.xq/content/modules.xml"}

return raddle:transpile("module(x,http://xxx.nl,bla),use(op),define(x:add2,(integer,integer,integer),number,(op:add($1,$2),op:add(.,$3)))",$params)

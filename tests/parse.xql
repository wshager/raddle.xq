xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

let $query := "define(count,(any*),number),define(avg,(any*),any),define(max,(any*),any),define(min,(any*),any),define(sum,(any*),any),define(tokenize,(string,string),string*)"
let $parsed := raddle:parse($query)
return serialize($parsed,
<output:serialization-parameters>
    <output:method>json</output:method>
</output:serialization-parameters>)
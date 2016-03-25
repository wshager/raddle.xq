xquery version "3.1";

module namespace xq="http://raddle.org/xquery";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace core="http://raddle.org/core" at "core.xql";

declare function xq:module($prefix,$ns,$desc) {
	concat("module namespace ", raddle:clip-string($prefix), "=", $ns, ";&#10;(:",$desc,":)")
};

declare function xq:function($name,$args,$type,$body) {
	let $args := array:for-each($args,function($_){
		apply(xq:typegen#4,$_)
	})
	return "declare function " || $name || "(" || string-join(array:flatten($args),",") || ") " || $type || " { " || $body || " };"
};

declare function xq:typegen($type,$name,$val,$suffix) {
	let $type := "xs:" || $type
	return
		if($val) then
			concat("let ",$name," as ",$type,$suffix," := ",$val," return ")
		else
			$name || " as xs:integer" || $suffix
};

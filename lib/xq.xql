xquery version "3.1";

module namespace xq="http://raddle.org/xquery";

import module namespace raddle="http://lagua.nl/lib/raddle" at "/db/apps/raddle.xq/content/raddle.xql";
import module namespace core="http://raddle.org/core" at "/db/apps/raddle.xq/lib/core.xql";
import module namespace console="http://exist-db.org/xquery/console";

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

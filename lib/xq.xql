xquery version "3.1";

module namespace xq="http://raddle.org/xquery";

import module namespace raddle="http://raddle.org/raddle" at "/db/apps/raddle.xq/content/raddle.xql";
import module namespace core="http://raddle.org/core" at "/db/apps/raddle.xq/lib/core.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare variable $xq:types := (
	"array",
	"attribute",
	"comment",
	"document-node",
	"element",
	"empty-sequence",
	"function",
	"item",
	"map",
	"namespace-node",
	"node",
	"processing-instruction",
	"schema-attribute",
	"schema-element",
	"text"
);

declare function xq:module($prefix,$ns,$desc) {
	concat("module namespace ", raddle:clip-string($prefix), "=", $ns, ";&#10;(:",$desc,":)")
};

declare function xq:import($prefix,$ns) {
	concat("import module namespace ", $prefix, "=&quot;", $ns, "&quot;;")
};

declare function xq:import($prefix,$ns,$loc) {
	concat("import module namespace ", $prefix, "=&quot;", $ns, "&quot; at &quot; ", $loc, "&quot;;")
};

declare function xq:define($name,$def,$args,$type,$body) {
	let $args := array:for-each($args,function($_){
		apply(xq:typegen#4,$_)
	})
	return "declare function " || $name || "(" || string-join(array:flatten($args),",") || ") " || $type || " { " || $body || " };"
};

declare function xq:function($args,$type,$body) {
	let $args := array:for-each($args,function($_){
		apply(xq:typegen#4,$_)
	})
	return "function(" || string-join(array:flatten($args),",") || ") " || $type || " { " || $body || " };"
};

declare function xq:typegen($frame,$type,$name,$val){
	xq:typegen($frame,$type,$name,$val,"")
};

declare function xq:typegen($frame,$type,$name,$val,$suffix) {
	let $type := if($type = $xq:types) then $type else "xs:" || $type
	return
		if($val) then
			concat("let ",$name," as ",$type,$suffix," := ",$val," return ")
		else
			$name || " as xs:integer" || $suffix
};

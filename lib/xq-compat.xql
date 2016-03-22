xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

declare variable $xqc:ncname := "\p{L}\p{N}\-_\."; (: actually variables shouldn't start with number :)
declare variable $xqc:qname := "[" || $xqc:ncname || "]*:?" || "[" || $xqc:ncname || "]+";
declare variable $xqc:operator-regexp := "=#\p{N}+#?\p{N}*=";

declare variable $xqc:operators := map {
	(:
	CompDocConstructor
	| CompElemConstructor
	| CompAttrConstructor
	| CompNamespaceConstructor
	| CompTextConstructor
	| CompCommentConstructor
	| CompPIConstructor
	:)
	2.01: "some",
	2.02: "every",
	2.03: "switch",
	2.04: "typeswitch",
	2.05: "try",
	2.06: "if",
	2.07: "then",
	2.08: "else",
	2.09: "let",
	2.10: ":=",
	2.11: "return",
	3: "or",
	4: "and",
	5.01: "eq",
	5.02: "ne",
	5.03: "lt",
	5.04: "le",
	5.05: "gt",
	5.06: "ge",
	5.07: "=",
	5.08: "!=",
	5.09: "<=",
	5.10: ">=",
	5.11: "<<",
	5.12: ">>",
	5.13: "<",
	5.14: ">",
	5.15: "is",
	6: "||",
	7: "to",
	8.01: "+",
	8.02: "-",
	9.01: "*",
	9.02: "idiv",
	9.03: "div",
	9.04: "mod",
	10.01: "union",
	10.02: "|",
	11.01: "intersect",
	11.02: "except",
	12: "instance of",
	13: "treat as",
	14: "castable as",
	15: "cast as",
	16: "=>",
	17.01: "+",
	17.02: "-",
	18: "!",
	19.01: "/",
	19.02: "//",
	20.01: "[",
	20.02: "]",
	20.03: "?",
	20.04: "[",
	20.05: "[",
	20.06: "{",
	20.07: "}",
	20.08: "@",
	21.01: "array",
	21.02: "attribute",
	21.03: "comment",
	21.04: "document",
	21.05: "element",
	21.06: "function",
	21.07: "map",
	21.08: "namespace",
	21.09: "processing-instruction",
	21.10: "text",
	(: leave type checks intact!
	22.01: "array",
	22.02: "attribute",
	22.03: "comment",
	22.04: "document-node",
	22.05: "element",
	22.06: "empty-sequence",
	22.07: "function",
	22.08: "item",
	22.09: "map",
	22.10: "namespace-node",
	22.11: "node",
	22.12: "processing-instruction",
	22.13: "schema-attribute",
	22.14: "schema-element",
	22.15: "text",
	 :)
	23: "as",
	24.01: "xquery version",
	24.02: "module namespace",
	24.03: "declare",
	24.04: "variable"
};

declare variable $xqc:types := [
	"untypedAtomic",
	"dateTime",
	"dateTimeStamp",
	"date",
	"time",
	"duration",
	"yearMonthDuration",
	"dayTimeDuration",
	"float",
	"double",
	"decimal",
	"integer",
	"nonPositiveInteger",
	"negativeInteger",
	"long",
	"int",
	"short",
	"byte",
	"nonNegativeInteger",
	"unsignedLong",
	"unsignedInt",
	"unsignedShort",
	"unsignedByte",
	"positiveInteger",
	"gYearMonth",
	"gYear",
	"gMonthDay",
	"gDay",
	"gMonth",
	"string",
	"normalizedString",
	"token",
	"language",
	"NMTOKEN",
	"Name",
	"NCName",
	"ID",
	"IDREF",
	"ENTITY",
	"boolean",
	"base64Binary",
	"hexBinary",
	"anyURI",
	"QName",
	"NOTATION"
];

declare variable $xqc:operator-map := map {
	5.01: "eq",
	5.02: "ne",
	5.03: "lt",
	5.04: "le",
	5.05: "gt",
	5.06: "ge",
	5.07: "geq",
	5.08: "gne",
	5.09: "gle",
	5.10: "gge",
	5.11: "precedes",
	5.12: "follows",
	5.13: "glt",
	5.14: "ggt",
	6: "concat",
	8.01: "add",
	8.02: "subtract",
	9.01: "multiply",
	10.02: "union",
	17.01: "plus",
	17.02: "minus",
	18: "for-each",
	19.01: "select",
	19.02: "select-all",
	20.01: "filter",
	20.03: "lookup",
	20.04: "array",
	20.05: "filter-at",
	20.08: "select-attribute"
};

declare function xqc:normalize-query($query as xs:string?,$params) {
	let $query := replace(replace(replace(replace(replace($query,"%3E",">"),"%3C","<"),"%2C",","),"%3A",":"),"&#9;|&#10;|&#13;"," ")
	(: TODO backwards support RQL, >= and <= will always be incompatible, use general comparisons instead :)
	(: normalize xquery :)
	(: prevent operator overwrites :)
	let $query := fold-left(map:keys($xqc:operators)[. ne 5.07],$query,function($cur,$next){
		if(round($next) ne 21 or matches($cur,xqc:prepare-for-regex($next))) then
			replace($cur,xqc:escape-for-regex($next),concat(" ",xqc:op-str($next)," "))
		else
			$cur
	})
	(: prevent = ambiguity :)
	let $query := replace($query,"=(#\p{N}+#?\p{N}*)=","%3D$1%3D")
	let $query := replace($query,"=","=#5#07=")
	let $query := replace($query,"%3D","=")
	let $query := replace($query,"(" || $xqc:operator-regexp || ")"," $1 ")
	let $query := replace($query,"\s+"," ")
	let $query := xqc:block(analyze-string($query,"(?:^?)([^\s\(\),\.;]+)(?:$?)")/*[name() = fn:match or matches(string(),"^\s*$") = false()],"")
	let $query := replace($query,"\s+","")
	(: TODO check if there are any ops left and either throw or fix :)
	return $query
};

declare function xqc:normalize-filter($query as xs:string?) {
	if(matches($query,"^([\+\-]?\p{N}+)|position$")) then (: TODO replace correct integers :)
		".=#5#07=" || $query
	else
		$query
};

declare function xqc:seqtype($parts,$ret,$params){
	let $head := head($parts)/fn:group[@nr=1]/string()
	let $maybe-seqtype := if(matches($head,$xqc:operator-regexp)) then xqc:op-num($head) else 0
	return
		if($maybe-seqtype eq 20.06) then
			xqc:body(tail($parts),concat($ret,",",string-join(for-each(1 to count($params),function($i){
				concat("=#2#09=(",replace($params[$i],"^\$",""),",$",$i,",")
			}))),$params ! xs:float(2.11))
		else if($maybe-seqtype eq 23) then
			xqc:seqtype(subsequence($parts,3),$ret || $parts[2]/string(),$params)
		else
			xqc:seqtype(tail($parts),$ret || "item()",$params)
};


declare function xqc:params($parts,$ret,$params){
	let $maybe-param := head($parts)/string()
	return
		if(matches($maybe-param,"\)")) then
			xqc:seqtype($parts,$ret || "),",$params)
		else if(matches($maybe-param,",")) then
			xqc:params(tail($parts),$ret || ",",$params)
		else if(matches($maybe-param,"^\$")) then
			let $next := $parts[2]/string()
			return
			if($next = "=#23=") then
				xqc:params(subsequence($parts,4),$ret || $parts[3]/string(),($params,$maybe-param))
			else
				xqc:params(tail($parts),$ret || "item()",($params,$maybe-param))
		else
			xqc:params(tail($parts),$ret,$params)
};

declare function xqc:fn($parts,$ret){
	(: TODO $parts(2) should be a paren, or error :)
	(: remove last } :)
	xqc:params(subsequence($parts,3,count($parts)-3),$ret || head($parts)/fn:group[@nr=1]/string() || ",(",()) || ")"
};

declare function xqc:ns($parts,$ret){
	let $ns := replace(head($parts)/string(),"\s","")
	let $rest := tail($parts)
	return string-join($rest)
};

declare function xqc:var($parts,$ret){
	let $ns := replace(head($parts)/string(),"\s","")
	let $rest := tail($parts)
	return string-join($rest)
};

declare function xqc:annot($parts,$ret){
	let $maybe-annot := head($parts)/fn:group[@nr=1]/string()
	let $rest := tail($parts)
	return
		if(matches($maybe-annot,"^%")) then
			xqc:annot($rest,$ret || $maybe-annot || "%")
		else if($maybe-annot = "=#21#06=") then
			xqc:fn($rest,$ret || "define(")
		else if($maybe-annot = "=#24#04=") then
			xqc:var($rest,$ret || "var(")
		else $ret
(:			xqc:decl(($maybe-annot,$rest),""):)
};

declare function xqc:decl($parts,$ret){
	let $type := head($parts)
	let $rest := tail($parts)
	return
		if($type = "function") then
			"define(" || xqc:fn($rest,$ret) || ")"
		else if($type = "variable") then
			"var(" || xqc:var($rest,$ret) || ")"
		else
			"ns(" || xqc:ns($rest,"") || ")"
};

declare function xqc:version($parts,$ret){
	xqc:block(tail($parts),concat($ret,"xq-version(",$parts[1]/string(),")"))
};

declare function xqc:module($parts,$ret){
	xqc:block(subsequence($parts,4),concat($ret,"module(",$parts[1]/string(),",",$parts[3]/string(),",())"))
};

declare function xqc:repl($lastseen as xs:float*,$no as xs:float){
	xqc:repl($lastseen,$no,$no - xs:float(0.01))
};

declare function xqc:repl($lastseen as xs:float*,$no as xs:float,$repl as xs:float){
	reverse(xqc:repl(reverse($lastseen),$no,$repl,()))
};

declare function xqc:repl($lastseen as xs:float*,$no as xs:float,$repl as xs:float,$ret as xs:float*){
	if(count($lastseen)>0) then
		if(head($lastseen) eq $repl) then
			($ret, $no, tail($lastseen))
		else
			xqc:repl(tail($lastseen),$no,$repl,($ret,head($lastseen)))
	else
		$ret
};

declare function xqc:close($lastseen as xs:float*,$no as xs:float,$close as xs:integer){
	if(empty($lastseen) or $close=0) then
		xqc:repl($lastseen,$no)
	else
		xqc:close(xqc:pop($lastseen),$no, $close - 1)
};

declare function xqc:appd($lastseen as xs:float*,$no as xs:float){
	($lastseen,$no)
};

declare function xqc:inst($lastseen as xs:float*,$no as xs:float,$before as xs:float){
	reverse(xqc:inst(reverse($lastseen),$no,$before,()))
};

declare function xqc:inst($lastseen as xs:float*,$no as xs:float,$before as xs:float, $ret as xs:float*){
	if(count($lastseen)>0) then
		if(head($lastseen) eq $before) then
			($ret, head($lastseen), $no, tail($lastseen))
		else
			xqc:inst(tail($lastseen),$no,$before,($ret,head($lastseen)))
	else
		$ret
};


declare function xqc:eq($a as xs:float,$b as xs:float*){
	$a = $b
};

declare function xqc:body($parts,$ret){
	xqc:body($parts,$ret,())
};

declare function xqc:closer($a as xs:float,$b as xs:float*){
	xqc:closer($a,tail(reverse($b)),0)
};

declare function xqc:closer($a as xs:float,$b as xs:float*,$c as xs:integer){
	if(empty($b) or xqc:eq($a,(2.08,2.11,20.07)) = false()) then
		$c
	else
		xqc:closer(head($b),tail($b),$c + 1)
};

declare function xqc:pop($a) {
	reverse(tail(reverse($a)))
};

declare function xqc:anon($head,$lastseen,$parts,$ret,$params) {
	if(matches($head,$xqc:operator-regexp) and xqc:op-num($head) eq 20.06) then
		xqc:body($parts,$ret,xqc:appd($lastseen,20.06))
	else
		if(matches($head,"^\$")) then
			let $rest := tail($parts)
			let $next := head($rest)/string()
			let $rest :=
				if($next = "=#23=") then
					(: expect a type and throw it away :)
					subsequence($rest,4)
				else if($next = ",") then
					tail($rest)
				else
					$rest
			return xqc:anon(head($parts)/string(),xqc:appd($lastseen,2.11),$rest,concat($ret,"=#2#09=(",replace($head,"^\$",""),",_",count($params),","),($params,$head))
		else
			xqc:anon(head($parts)/string(),$lastseen,tail($parts),$ret,$params)
};

declare function xqc:body-op($no,$next,$lastseen,$rest,$ret){
	if($no eq 21.06) then
		xqc:anon($next,xqc:appd($lastseen,$no),tail($rest),$ret,())
	else
		let $old := $lastseen
		let $prevseen := if(empty($lastseen)) then 0 else $lastseen[last()]
		let $positional := $no eq 20.01 and $next and matches($next,"^([\+\-]?\p{N}+)|position$")
		let $close :=
			if(xqc:eq($no,(2.08,2.11,20.07)) and xqc:eq($prevseen,(2.08,2.11,20.07))) then
				xqc:closer($prevseen,$lastseen)
			else
				0
		let $ret := concat($ret,
			if(xqc:eq($no,(2.06,2.09,20.01,20.04))) then
				concat(
					if(xqc:eq($no, 2.09) and xqc:eq($prevseen,2.10)) then "," else "",
					if($positional) then
						xqc:op-str(20.05)
					else
						xqc:op-str($no),
					if($no eq 2.06) then "" else "(",
					if(xqc:eq($no, 2.09)) then
						replace($next,"^\$|\s","")
					else if(xqc:eq($no, 20.01)) then
						(: prepare filter :)
						concat(
							if(matches($next,"#20#08")) then
								"."
							else if($positional) then
								if(matches($next,"position")) then
									"."
								else
									".=#5#07="
							else ""
						, $next)
					else ""
				)
			else if(xqc:eq($no, (2.07,2.08,2.10,2.11,20.07))) then
				concat(if($close>0) then string-join((1 to $close) ! ")") else "", if($no eq 20.07) then "" else ",")
			else if(xqc:eq($no,20.02)) then
				")"
			else if($no eq 20.06) then
				"("
			else
				xqc:op-str($no))
		let $rest :=
			if(empty($rest) or xqc:eq($no,(2.09, 20.01)) = false()) then
				$rest
			else
				tail($rest)
		let $lastseen :=
			if(xqc:eq($no, (2.06,2.09,20.01))) then
				if(xqc:eq($no, 2.09) and xqc:eq($prevseen,2.10)) then
					(: push explicit return :)
					xqc:appd($lastseen,2.11)
				else
					xqc:appd($lastseen,$no)
			else if(xqc:eq($no, (2.07,2.08,2.10,2.11,20.07))) then
				if($close>0) then
					xqc:close($lastseen,$no,$close)
				else
					xqc:repl($lastseen,$no)
			else if(round($no) eq 21) then
				xqc:appd($lastseen,$no)
			else if($no eq 20.06 and round($prevseen) eq 21) then (: the prevseen check should be redundant :)
				xqc:appd(xqc:pop($lastseen),$prevseen)
			else if($no eq 20.02) then
				xqc:pop($lastseen)
			else
				$lastseen
(:		let $nu := console:log($close || " :: " || string-join($old,",") || " -> " || string-join($lastseen,",") || " || " || replace(replace($ret,"=#2#06=","if"),"=#2#09=","let")):)
		return xqc:body($rest,$ret,$lastseen)
};

declare function xqc:is-array($head,$non){
	$non eq 20.01 and matches($head,"^(\s|\(|,|" || $xqc:operator-regexp || ")")
};

declare function xqc:body($parts,$ret,$lastseen){
	if(empty($parts)) then
		concat($ret, string-join($lastseen[xqc:eq(.,(2.08,2.11))] ! ")"))
	else
		let $head := head($parts)/string()
		let $rest := tail($parts)
		let $next := if(empty($rest)) then () else head($rest)/string()
		let $non :=
			if(matches($next,$xqc:operator-regexp)) then
				xqc:op-num($next)
			else
				0
		let $rest :=
			if(xqc:is-array($head,$non)) then
				insert-before(tail($rest),1,element fn:match {
					element fn:group {
						attribute nr { 1 },
						xqc:op-str(20.04)
					}
				})
			else
				$rest
		return
			if(matches($head,$xqc:operator-regexp)) then
				xqc:body-op(xqc:op-num($head),$next,$lastseen,$rest,$ret)
(:			else if(matches($head,"^\$") and matches($head,":")=false()) then:)
(:				xqc:body($rest,$lastseen,concat($ret,"_",$params($head)),$params):)
			else
				xqc:body($rest,
					if(xqc:eq($non,(2.06,2.09,21.06)) and matches($head,",|\(") = false()) then
						concat($ret,$head,",")
					else
						concat($ret,$head),
				$lastseen)
};

declare function xqc:block($parts,$ret){
	if(empty($parts)) then
		$ret
	else
		let $val := head($parts)/string()
		let $rest := tail($parts)
		return
			if(matches($val,$xqc:operator-regexp)) then
				let $no := xqc:op-num($val)
				return
					if($no eq 24.01) then
						xqc:version($rest,$ret)
					else if($no eq 24.02) then
						xqc:module($rest,$ret)
					else if($no eq 24.03) then
						xqc:annot($rest,$ret)
					else
						xqc:body($rest,$ret)
			else if(matches($val,";")) then
				if(empty($rest)) then
					$ret
				else
					xqc:block($rest,$ret || ",")
			else
				xqc:body($parts,$ret)
};


declare function xqc:operator-precedence($val,$operator,$ret){
	let $rev := array:reverse($ret)
	let $last := array:head($rev)
	let $has-preceding-op := $last instance of map(xs:string?,item()?) and matches($last("name"),$xqc:operator-regexp)
	(: for unary operators :)
	let $is-unary-op := xqc:op-int($operator) = 8 and $has-preceding-op and $last("suffix") = false()
	let $operator :=
		if($is-unary-op) then
			xqc:unary-op($operator)
		else
			$operator
	let $preceeds := $has-preceding-op and xqc:op-int($operator) > xqc:op-int($last("name"))
	let $name :=
		if($preceeds) then
			$last("name")
		else
			$operator
	let $args :=
		if($preceeds) then
			(: if operator > preceding swap the nesting :)
			let $argsize := array:size($last("args"))
			let $nargs :=
				if($is-unary-op) then
					[]
				else
					[$last("args")(2)]
			let $nargs :=
				if($val) then
					array:append($nargs,$val)
				else
					$nargs
			return if($argsize>1 and $is-unary-op) then
				let $pre := $last("args")(2)
				return [
					$last("args")(1),
					map {
						"name" := $pre("name"),
						"args" := array:append($pre("args"),map { "name" := $operator, "args" :=$nargs, "suffix" := ""}),
						"suffix" := ""
					}]
			else
				[$last("args")(1),map { "name" := $operator, "args" :=$nargs, "suffix" := ""}]
		else
			let $nargs := [$last]
			return
				if($val) then
					array:append($nargs,$val)
				else
					$nargs
	(: FIXME misuse of suffix for unary ops... :)
	return array:append(array:reverse(array:tail($rev)),map { "name" := $name, "args" := $args, "suffix" := exists($val)})
};

declare function xqc:to-op($opnum){
	if(map:contains($xqc:operator-map,$opnum)) then
		$xqc:operator-map($opnum)
	else
		replace($xqc:operators($opnum)," ","-")
};

declare function xqc:rename($a,$fn) {
	array:for-each($a,function($t){
		if($t instance of map(xs:string?,item()?)) then
			map {
				"name": $fn($t("name")),
				"args": xqc:rename($t("args"),$fn),
				"suffix": $t("suffix")
			}
		else
			$t
	})
};

declare function xqc:escape-for-regex($key) as xs:string {
	let $arg := $xqc:operators($key)
	return
		if(matches($arg,"\p{L}+")) then
			if($arg = "if" or round($key) = 21) then
				"(^|\s|,|\()" || $arg || "\s?"
			else if($arg = "then") then
				"\)\s*" || $arg
			else
				"(^|\s)" || $arg || "(\s|$)"
		else
			let $arg := replace($arg,"(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))","\\$1")
			return
				if($key eq 20.03) then
					"\s?" || $arg || "\s?[" || $xqc:ncname || "\(]+"
				else if($key = (8.02,17.02)) then
					"(^|\s)" || $arg || "(\s)?"
				else
					"\s?" || $arg || "\s?"
};

declare function xqc:prepare-for-regex($key) as xs:string {
	let $arg := $xqc:operators($key)
	return
		(: constructors :)
		if($key eq 21.06) then
			"(^|\s)" || $arg || "[\s" || $xqc:ncname || ":]*\([\s\$" || $xqc:ncname || ",:\)]*=#20#06"
		else
			"(^|\s)" || $arg || "[\s\$" || $xqc:ncname || ",:]*=#20#06"
};


declare function xqc:unary-op($op){
	xqc:op-str(xqc:op-num($op) + 9)
};

declare function xqc:op-int($op){
	number(replace($op,"^=#(\p{N}+)#?\p{N}*=$","$1"))
};

declare function xqc:op-num($op) as xs:float {
	xs:float(replace($op,"^=#(\p{N}+)#?(\p{N}*)=$","$1.$20"))
};

declare function xqc:op-str($op){
	concat("=#",replace(string($op),"\.","#"),"=")
};
xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

import module namespace console="http://exist-db.org/xquery/console";

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
	1: ",",
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
	23.01: "xquery",
	23.02: "version",
	23.03: "module",
	23.04: "declare",
	23.05: "variable",
	23.06: "import",
	23.07: "at",
	24: "as",
	25.01: "(:",
	25.02: ":)",
	26: ":"
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
		replace($cur,xqc:escape-for-regex($next),concat("$1 ",xqc:op-str($next)," $2"))
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

declare function xqc:seqtype($parts,$ret){
	let $head := head($parts)/fn:group[@nr=1]/string()
	let $maybe-seqtype := if(matches($head,$xqc:operator-regexp)) then xqc:op-num($head) else 0
	return
		if($maybe-seqtype eq 20.06) then
			xqc:body(tail($parts),concat($ret,","),(20.06))
		else if($maybe-seqtype eq 24) then
			xqc:seqtype(subsequence($parts,3),$ret || $parts[2]/string())
		else
			xqc:seqtype(tail($parts),$ret || "item()")
};

declare function xqc:as($param,$parts,$ret){
	let $next := $parts[2]/string()
	return
		if(matches($next,$xqc:operator-regexp)) then
			xqc:params(subsequence($parts,3),concat($ret,head($parts)/string(),"(",$param,")",$xqc:operators(xqc:op-num($next))))
		else
			xqc:params(tail($parts),concat($ret,head($parts)/string(),"(",$param,")"))
};

declare function xqc:params($parts,$ret){
	let $maybe-param := head($parts)/string()
	return
		if(matches($maybe-param,"\)")) then
			xqc:seqtype($parts,$ret || "),")
		else if(matches($maybe-param,"=#1=")) then
			xqc:params(tail($parts),concat($ret,","))
		else if(matches($maybe-param,",")) then
			xqc:params(tail($parts),$ret || ",")
		else if(matches($maybe-param,"^\$")) then
			let $next := $parts[2]/string()
			return
			if($next = "=#24=") then
				xqc:as(replace($maybe-param,"^\$",""),subsequence($parts,3),$ret)
			else
				xqc:params(tail($parts),$ret || replace($maybe-param,"^\$",""))
		else
			xqc:params(tail($parts),$ret)
};

declare function xqc:fn($parts,$ret){
	(: TODO $parts(2) should be a paren, or error :)
	(: remove last } :)
	xqc:params(subsequence($parts,3),$ret || head($parts)/fn:group[@nr=1]/string() || ",(")
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
			xqc:fn($rest,$ret || "core:define($,")
		else if($maybe-annot = "=#23#05=") then
			xqc:var($rest,$ret || "core:var(")
		else $ret
(:			xqc:decl(($maybe-annot,$rest),""):)
};

declare function xqc:decl($parts,$ret){
	let $type := head($parts)
	let $rest := tail($parts)
	return
		if($type = "function") then
			"core:define($," || xqc:fn($rest,$ret)
		else if($type = "variable") then
			"core:var($," || xqc:var($rest,$ret)
		else
			"core:xmlns($," || xqc:ns($rest,"")
};

declare function xqc:xquery($parts,$ret){
	xqc:block(subsequence($parts,3),concat($ret,"core:xq-version($,",$parts[2]/string(),")"))
};

declare function xqc:module($parts,$ret){
	xqc:block(subsequence($parts,5),concat($ret,"core:module($,",$parts[2]/string(),",",$parts[4]/string(),",())"))
};

declare function xqc:repl($lastseen as xs:decimal*,$no as xs:decimal){
	xqc:repl($lastseen,$no,$no - xs:decimal(0.01))
};

declare function xqc:repl($lastseen as xs:decimal*,$no as xs:decimal,$repl as xs:decimal){
	reverse(xqc:repl(reverse($lastseen),$no,$repl,()))
};

declare function xqc:repl($lastseen as xs:decimal*,$no as xs:decimal,$repl as xs:decimal,$ret as xs:decimal*){
	if(count($lastseen)>0) then
		if(head($lastseen) eq $repl) then
			($ret, $no, tail($lastseen))
		else
			xqc:repl(tail($lastseen),$no,$repl,($ret,head($lastseen)))
	else
		$ret
};

declare function xqc:close($lastseen as xs:decimal*,$no as xs:decimal,$close as xs:integer){
	if(empty($lastseen) or $close=0) then
		xqc:repl($lastseen,$no)
	else
		xqc:close(xqc:pop($lastseen),$no, $close - 1)
};

declare function xqc:appd($lastseen as xs:decimal*,$no as xs:decimal){
	($lastseen,$no)
};

declare function xqc:inst($lastseen as xs:decimal*,$no as xs:decimal,$before as xs:decimal){
	reverse(xqc:inst(reverse($lastseen),$no,$before,()))
};

declare function xqc:inst($lastseen as xs:decimal*,$no as xs:decimal,$before as xs:decimal, $ret as xs:decimal*){
	if(count($lastseen)>0) then
		if(head($lastseen) eq $before) then
			($ret, head($lastseen), $no, tail($lastseen))
		else
			xqc:inst(tail($lastseen),$no,$before,($ret,head($lastseen)))
	else
		$ret
};


declare function xqc:eq($a as xs:decimal,$b as xs:decimal*){
	$a = $b
};

declare function xqc:body($parts,$ret){
	xqc:body($parts,$ret,())
};

declare function xqc:closer($a as xs:decimal,$b as xs:decimal*){
	xqc:closer($a,tail(reverse($b)),0)
};

declare function xqc:closer($a as xs:decimal,$b as xs:decimal*,$c as xs:integer){
	if(empty($b) or xqc:eq($a,(2.08,2.11)) = false()) then
		$c
	else
		xqc:closer(head($b),tail($b),$c + 1)
};

declare function xqc:last-index-of($lastseen as xs:decimal*,$a as xs:decimal) {
	let $id := index-of($lastseen,$a)
	return
		if(empty($id)) then 1 else $id[last()]
};

declare function xqc:pop($a) {
	reverse(tail(reverse($a)))
};

declare function xqc:anon($head,$parts,$ret,$lastseen) {
	let $op := if(matches($head,$xqc:operator-regexp)) then xqc:op-num($head) else 0
	let $next := head($parts)/string()
	return
	if($op eq 20.06) then
		xqc:body($parts,$ret,xqc:appd($lastseen,$op))
	else if($op eq 1) then
		xqc:anon(head($parts)/string(),tail($parts),concat($ret,","),$lastseen)
	else if(matches($head,"=#1=")) then
		xqc:params(tail($parts),concat($ret,","))
	else if(matches($head,"^\$")) then
		if($next = "=#24=") then
			xqc:anon($next,subsequence($parts,3),concat($ret,$parts[2]/string(),"(",replace($head,"^\$",""),")"),$lastseen)
		else
			xqc:anon($next,tail($parts),$ret || replace($head,"^\$",""),$lastseen)
	else if(matches($head,"^\)")) then
		if($next = "=#24=") then
			xqc:anon($next,subsequence($parts,3),concat($ret,"),",$parts[2]/string(),"(),"),$lastseen)
		else
			xqc:anon($next,tail($parts),$ret || "),item(),",$lastseen)
	else
		xqc:anon(head($parts)/string(),tail($parts),$ret,$lastseen)
};

declare function xqc:map($parts,$ret,$lastseen){
	let $head := head($parts)/string()
(:	let $n := console:log($head):)
	let $op := if(matches($head,$xqc:operator-regexp)) then xqc:op-num($head) else 0
	return
(:		if($op eq 20.07) then:)
(:			xqc:body($parts,$ret,$lastseen):)
(:		else:)
			xqc:body($parts,$ret, $lastseen)
};

declare function xqc:comment($parts,$ret,$lastseen) {
	let $head := head($parts)/string()
	let $rest := tail($parts)
	return
		if($head = "=#25#02=") then
			xqc:body($rest,$ret,$lastseen)
		else
			xqc:comment($rest,$ret,$lastseen)
};

declare function xqc:body-op($no,$next,$lastseen,$rest,$ret){
	if($no eq 1) then
		xqc:body($rest,concat($ret,","),$lastseen)
	else if($no eq 26) then
		xqc:body($rest,concat($ret,","),xqc:appd($lastseen,$no))
	else if($no eq 25.01) then
		xqc:comment($rest,$ret,$lastseen)
	else if($no eq 21.06) then
		xqc:anon($next,tail($rest),concat($ret,"=#21#06=(("),$lastseen)
	else if($no eq 21.07) then
		xqc:map(tail($rest),concat($ret,"map:new("),xqc:appd($lastseen,20.06))
	else
		let $old := $lastseen
		let $prevseen := if(empty($lastseen)) then 0 else $lastseen[last()]
		let $positional := $no eq 20.01 and $next and matches($next,"^([\+\-]?\p{N}+)|position$")
		let $close :=
			if(xqc:eq($no,(2.08,2.11)) and xqc:eq($prevseen,(2.08,2.11))) then
				xqc:closer($prevseen,subsequence($lastseen,xqc:last-index-of($lastseen,20.06),count($lastseen)))
			else
				0
		let $ret := concat($ret,
			if(xqc:eq($no,(2.06,2.09,20.01,20.04))) then
				concat(
					if(xqc:eq($no, 2.09) and xqc:eq($prevseen,(2.10,2.11)) and substring($ret,string-length($ret)) ne ",") then "," else "",
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
			else if($no eq 20.07) then
				let $lastindex := xqc:last-index-of($lastseen,20.06)
				(: add one extra closed paren by consing 2.11 :)
				return string-join((subsequence($lastseen,$lastindex,count($lastseen)),2.11)[xqc:eq(.,(2.08,2.10,2.11))] ! ")")
			else if(xqc:eq($no, (2.07,2.08,2.10,2.11))) then
				concat(if($close>0) then string-join((1 to $close) ! ")") else "",",")
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
			else if($no = 20.07) then
				(: eat up until 20.06 AND the block opener :)
				let $lastseen := subsequence($lastseen,1,xqc:last-index-of($lastseen,20.06) - 1)
(:				let $n := console:log("from ender " || string-join($lastseen,",")):)
				return
(:					if(round($lastseen[last()]) eq 21) then:)
(:						reverse(tail(reverse($lastseen))):)
(:					else:)
						$lastseen
			else if(xqc:eq($no, (2.07,2.08,2.10,2.11))) then
				if($close>0) then
					xqc:close($lastseen,$no,$close)
				else
					xqc:repl($lastseen,$no)
			else if($no eq 20.06 or round($no) eq 21) then
				xqc:appd($lastseen,$no)
			else if($no eq 20.02) then
				xqc:pop($lastseen)
			else
				$lastseen
		let $nu := console:log($no || " x " ||$close || " :: " || string-join($old,",") || " -> " || string-join($lastseen,",") || " || " || replace(replace($ret,"=#2#06=","if"),"=#2#09=","let"))
		return xqc:body($rest,$ret,$lastseen)
};

declare function xqc:is-array($head,$non){
	$non eq 20.01 and matches($head,"^(\s|\(|,|" || $xqc:operator-regexp || ")")
};

declare function xqc:body($parts,$ret,$lastseen){
	if(empty($parts)) then
		concat($ret, string-join($lastseen[xqc:eq(.,(2.08,2.11,20.07))] ! ")"))
	else
		let $head := head($parts)/string()
		let $rest := tail($parts)
		return
			if($head = "=#25#01=") then
				xqc:comment($rest,$ret,$lastseen)
			else if(matches($head,";")) then
				xqc:block($parts, $ret)
			else
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

declare function xqc:import($parts,$ret) {
	let $rest := subsequence($parts,6)
	let $maybe-at := head($rest)/string()
(:	let $n := console:log($maybe-at):)
	return
		if($maybe-at = "=#23#07=") then
			xqc:block(subsequence($rest,3),concat($ret,"core:import($,",$parts[3]/string(),",",$parts[5]/string(),",",$rest[2]/string(),")"))
		else
			xqc:block($rest,concat($ret,"core:import($,",$parts[3]/string(),",",$parts[5]/string(),")"))
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
					if($no eq 23.01) then
						xqc:xquery($rest,$ret)
					else if($no eq 23.03) then
						xqc:module($rest,$ret)
					else if($no eq 23.04) then
						xqc:annot($rest,$ret)
					else if($no eq 23.06) then
						xqc:import($rest,$ret)
					else
						xqc:body($parts,$ret)
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
		"core:" || $xqc:operator-map($opnum)
	else
		"core:" || replace($xqc:operators($opnum)," ","-")
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
			if($key eq 21.06) then
				"(^|\s|,|\(|;)" || $arg || "([\s" || $xqc:ncname || ":]*\s*\([\s\$" || $xqc:ncname || ",:#=]*\)\s*=#20#06=)"
			else if(round($key) = 21) then
				"(^|\s|,|\(|;)" || $arg || "([\s\$" || $xqc:ncname || ",:]*=#20#06)"
			else if(round($key) = 24) then
				"(^|\s|,|\(|;)" || $arg || "(\s)"
			else if($arg = "if") then
				"(^|\s|,|\(|;)" || $arg || "(\s?)"
			else if($arg = "then") then
				"\)(\s*)" || $arg || "(\s?)"
			else
				"(^|\s)" || $arg || "(\s|$)"
		else
			let $arg := replace($arg,"(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))","\\$1")
			return
				if($key eq 26) then
					"(\s?)" || $arg || "(\s*[^\p{L}])"
				else if($key eq 2.10) then
					"(\s?):\s*=(\s?)"
				else if($key eq 20.03) then
					"(\s?)" || $arg || "(\s*[" || $xqc:ncname || "\(]+)"
				else if($key = (8.02,17.02)) then
					"(^|\s)" || $arg || "(\s)?"
				else
					"(\s?)" || $arg || "(\s?)"
};

declare function xqc:unary-op($op){
	xqc:op-str(xqc:op-num($op) + 9)
};

declare function xqc:op-int($op){
	xs:decimal(replace($op,"^=#(\p{N}+)#?\p{N}*=$","$1"))
};

declare function xqc:op-num($op) as xs:decimal {
	xs:decimal(replace($op,"^=#(\p{N}+)#?(\p{N}*)=$","$1.$20"))
};

declare function xqc:op-str($op){
	concat("=#",replace(string($op),"\.","#"),"=")
};

xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";

declare variable $xqc:ncname := "\p{L}\p{N}\-_\.@";
declare variable $xqc:qname := "^(\p{L}|@)[" || $xqc:ncname || "]*:?" || "[" || $xqc:ncname || "]*";
declare variable $xqc:operator-regexp := "=#\p{N}+=";

declare variable $xqc:operators as map(xs:integer, xs:string) := map {
	(:
	CompDocConstructor
	| CompElemConstructor
	| CompAttrConstructor
	| CompNamespaceConstructor
	| CompTextConstructor
	| CompCommentConstructor
	| CompPIConstructor
	:)
	201: "some",
	202: "every",
	203: "switch",
	204: "typeswitch",
	205: "try",
	206: "if",
	207: "then",
	208: "else",
	209: "let",
	210: ":=",
	211: "return",
	212: "case",
	213: "default",
	214: "xquery",
	215: "version",
	216: "module",
	217: "declare",
	218: "variable",
	219: "import",
	220: "at",
	221: "for",
	222: "in",
	223: "group by",
	300: "or",
	400: "and",
	501: "eq",
	502: "ne",
	503: "lt",
	504: "le",
	505: "gt",
	506: "ge",
	507: "=",
	508: "!=",
	509: "<=",
	510: ">=",
	511: "<<",
	512: ">>",
	513: "<",
	514: ">",
	515: "is",
	600: "||",
	700: "to",
	801: "+",
	802: "-",
	901: "*",
	902: "idiv",
	903: "div",
	904: "mod",
	1001: "union",
	1002: "|",
	1101: "intersect",
	1102: "except",
	1200: "instance of",
	1300: "treat as",
	1400: "castable as",
	1500: "cast as",
	1600: "=>",
	1701: "+",
	1702: "-",
	1800: "!",
	1901: "/",
	2003: "?",
	2101: "array",
	2102: "attribute",
	2103: "comment",
	2104: "document",
	2105: "element",
	2106: "function",
	2107: "map",
	2108: "namespace",
	2109: "processing-instruction",
	2110: "text",
	2201: "array",
	2202: "attribute",
	2203: "comment",
	2204: "document-node",
	2205: "element",
	2206: "empty-sequence",
	2207: "function",
	2208: "item",
	2209: "map",
	2210: "namespace-node",
	2211: "node",
	2212: "processing-instruction",
	2213: "schema-attribute",
	2214: "schema-element",
	2215: "text",
	2400: "as",
	2501: "(:",
	2502: ":)",
	2600: ":"
};

(: TODO increase / decrease depth, comma depth stays same:)
declare variable $xqc:block-chars := (
    "[","]","{","}","(",")",","
);


declare variable $xqc:types := (
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
);

declare variable $xqc:operator-map as map(xs:integer, xs:string) := map {
	206: "iff",
	209: "item",
	501: "eq",
	502: "ne",
	503: "lt",
	504: "le",
	505: "gt",
	506: "ge",
	507: "geq",
	508: "gne",
	509: "gle",
	510: "gge",
	511: "precedes",
	512: "follows",
	513: "glt",
	514: "ggt",
	600: "concat",
	801: "add",
	802: "subtract",
	901: "multiply",
	1002: "union",
	1701: "plus",
	1702: "minus",
	1800: "for-each",
	1901: "select",
(:	1902: "select-deep",:)
	2001: "filter",
	2003: "lookup",
	2004: "array",
	2701: "pair"
};


declare variable $xqc:operators-inv := fold-left(map:keys($xqc:operators),map {},function($pre,$cur){
    map:put($pre,$xqc:operators($cur),$cur)
});

declare variable $xqc:lr-op as xs:integer* := (
	300,
	400,
	501,
	502,
	503,
	504,
	505,
	506,
	507,
	508,
	509,
	510,
	511,
	512,
	513,
	514,
	515,
	600,
	700,
	801,
	802,
	901,
	902,
	903,
	904,
	1001,
	1002,
	1101,
	1102,
	1200,
	1300,
	1400,
	1500,
	1800,
	1901,
	2003,
	2400
);

declare variable $xqc:fns := (
	"position","last","name","node-name","nilled","string","data","base-uri","document-uri","number","string-length","normalize-space"
);

declare function xqc:normalize-query($query as xs:string?,$params) {
	let $query := replace(replace(replace(replace($query,"%3E",">"),"%3C","<"),"%2C",","),"%3A",":")
	(: hack for suffix :)
	let $query := replace($query,"([\*\+\?])\s+([,\)\{])","$1$2")
	let $keys := for $k in map:keys($params("$operators")) order by xs:integer($k) return $k
	let $query := fold-left($keys[. ne 507 and . ne 1],$query,function($cur,$next){
		replace($cur,xqc:escape-for-regex($next,$params),if($next idiv 100 eq 22) then concat("$1",xqc:to-op($next,$params),"$2") else concat("$1 ",xqc:op-str($next)," $2"))
	})
	let $query := fold-left($xqc:types,$query,function($cur,$next){
		let $cur := replace($cur,concat("xs:",$next,"\s*([^\(])"),concat("core:",$next,"()$1"))
		return replace($cur,concat("xs:",$next,"\s*\("),concat("core:",$next,"("))
	})
	(: prevent = ambiguity :)
	let $query := replace($query,",","=#1=")
	let $query := replace($query,"=(#\p{N}+)=","%3D$1%3D")
	let $query := replace($query,"=","=#507=")
	let $query := replace($query,"%3D","=")
	let $query := replace($query,"(" || $xqc:operator-regexp || ")"," $1 ")
	let $query := replace($query,"\s+"," ")
	(: FIXME consider axes :)
	let $query := replace($query,"=#1901=\s*=#1901=","=#1901= descendant::")
(:	let $query := xqc:block(analyze-string($query,"([^\s\(\),\.;]+)")/*[name(.) = fn:match or matches(string(.),"^\s*$") = false()],""):)
    let $query := for-each(tokenize($query,";"),function($cur){
        let $parts := analyze-string($cur,"([^\s\(\),\.]+)")/*[name(.) = fn:match or matches(string(.),"^\s*$") = false()]
        let $ret := xqc:block($parts,"")
        return if($ret) then replace($ret,"\s+","") else ()
    })
	(: TODO check if there are any ops left and either throw or fix :)
	return $query
};

declare variable $xqc:uri-chars := map {
    "%3E" : ">",
    "%3C" : "<",
    "%2C" : ",",
    "%3A" : ":"
};

declare function xqc:inspect-buf($acc,$params){
    if(string-length($acc) eq 1 and $acc = $xqc:block-chars) then
        string-to-codepoints($acc)
    else if(map:contains($xqc:operators-inv,$acc)) then
        $xqc:operators-inv($acc)
    else
        ()
};

(:
- we have chunks now (based on WS, FAST!) but the problem is that each chunk can contain any char, so:
- check for single BLOCK chars (unique)
- reintroduce DAWG to create matches on buffer, only if there's a complete match insert it, continue with next
- we need DAWG because partial checks must yield something, or we match try to match something else
 :)
declare function xqc:process-chars($chars,$ret,$params){
    if(count($chars) gt 0) then
        let $c := head($chars)
        let $acc := concat($ret(1), $c)
        let $lastseen := $ret(2)
        let $entry := xqc:inspect-buf($acc,$params)
        (: if have match, flush buffer :)
        let $ret :=
            if($entry) then
                let $ret := a:put($ret, 1, "")
                let $ret := a:put($ret, 2, "")
                return array:append($ret,$entry)
            else
                let $ret := a:put($ret, 1, $acc)
                return a:put($ret, 2, $c)
        return xqc:process-chars(tail($chars), $ret,$params)
    else
        let $acc := $ret(1)
        return array:append(a:put(a:put($ret,2,$acc),1,""),xqc:inspect-buf($acc,$params))
};

declare function xqc:process-buffer($buf,$ret,$params){
    let $chars := analyze-string($buf,".")/fn:match/string()
    return if(count($chars) gt 0) then
        xqc:process-chars($chars,$ret,$params)
    else
        $ret
};

declare function xqc:normalize-query-b($query as xs:string?,$params) {
    for-each(tokenize($query,";"),function($part){
        array:for-each(array { tokenize($part,"\s+") },function($buf){
            xqc:process-buffer($buf, ["",""], $params)
        })
    })
};


declare function xqc:seqtype($parts,$ret,$lastseen){
	(: TODO check empty (never was an as) and complex type :)
	let $head := head($parts)/fn:group[@nr=1]/string()
	let $maybe-seqtype := if(matches($head,$xqc:operator-regexp)) then xqc:op-num($head) else 0
	return
		if($maybe-seqtype eq 2006) then
			xqc:body($parts,concat($ret,","),array:append($lastseen,2106))
		else
			xqc:seqtype(tail($parts),$ret,$lastseen)
};

declare function xqc:as($param,$parts,$ret,$lastseen,$subtype,$seqtype){
	let $head := head($parts)/string()
	let $next := $parts[2]/string()
	let $no :=
		if(matches($head,$xqc:operator-regexp)) then
			xqc:op-num($head)
		else
			0
	let $non :=
		if(matches($next,$xqc:operator-regexp)) then
			xqc:op-num($next)
		else
			0
	return
		if($no eq 2006) then
			xqc:body($parts,concat($ret,if($subtype) then ")" else "",","),array:append($lastseen,2106))
		else if($no eq 2400) then
			(: function seq type :)
			xqc:as($param,tail($parts),concat($ret,if($subtype) then ")" else "",","),$lastseen,$subtype,true())
		else if($no eq 1) then
			if($subtype) then
				xqc:as($param,tail($parts),concat($ret,","),$lastseen,$subtype,$seqtype)
			else
				xqc:params(tail($parts),concat($ret,","))
		else if(matches($head,concat("core:[",$xqc:ncname,"]+"))) then
			if(matches($next,"^\s*\(\s*$")) then
				(: complex subtype opener :)
				xqc:as((),subsequence($parts,3),concat($ret,$head,"(",$param,",",if($head eq "core:anon") then "(" else ""),$lastseen,true(),$seqtype)
			else
				xqc:as((),tail($parts),concat($ret,$head,"(",$param,if($head eq "core:anon") then ",(" else ""),$lastseen,$subtype,$seqtype)
		else if(matches($head,"[\?\+\*]")) then
			xqc:as($param,tail($parts),concat($ret,$head),$lastseen,$subtype,$seqtype)
		else if(matches($head,"^(\(\))?\s*\)")) then
			(: TODO combine these :)
			if($subtype and $non = (1,2400)) then
				xqc:as($param,tail($parts),concat($ret,if($non eq 2400) then "" else ")"),$lastseen,false(),$seqtype)
			else if($non eq 2400) then
				xqc:as((),tail($parts),concat($ret,if($subtype) then ")" else "","))"),$lastseen,false(),false())
			else if($non eq 2006) then
				xqc:body(tail($parts),concat($ret,if($subtype) then ")" else "",if(matches($head,"^\(\)")) then ")" else "","),core:item(),"),array:append($lastseen,2106))
			else
				(: what? :)
				(("what",$parts))
		else
			(: FIXME check seqtype vs subtype :)
			(: TODO add default values
			if($non eq 21) then
        		    xqc:body(tail($parts),concat($ret,""),($lastseen))
        		else  :)
			xqc:as($param,tail($parts),concat($ret,if($non eq 1 and $seqtype) then ")" else "",")"),$lastseen,$subtype,$seqtype)
};

declare function xqc:params($parts,$ret){
    xqc:params($parts,$ret,[])
};

declare function xqc:params($parts,$ret,$lastseen){
	let $maybe-param := head($parts)/string()
	let $rest := tail($parts)
	return
		if(matches($maybe-param,"^\(?\s*\)")) then
			if(head($rest)/string() eq "=#2400=") then
				xqc:as((),$rest,concat($ret,")"),$lastseen,false(),false())
			else
				xqc:body($rest,concat($ret,"),core:item(),"),array:append($lastseen,2106))
		else if(matches($maybe-param,"=#1=")) then
			xqc:params($rest,concat($ret,","),$lastseen)
		else if(matches($maybe-param,"^\$")) then
			if(head($rest)/string() eq "=#2400=") then
				xqc:as(replace($maybe-param,"^\$","\$,"),tail($rest),$ret,$lastseen,false(),false())
			else
				xqc:params($rest,concat($ret,"core:item(",replace($maybe-param,"^\$","\$,"),")"),$lastseen)
		else
			xqc:params($rest,$ret,$lastseen)
};

declare function xqc:xfn($parts,$ret){
	(: TODO $parts(2) should be a paren, or error :)
	xqc:params(tail($parts),concat($ret, head($parts)/fn:group[@nr=1]/string(), ",(),("))
};

declare function xqc:xvar($parts,$ret){
	xqc:body(subsequence($parts,3),concat($ret,$parts[1]/string(),",(),"),[218])
};

declare function xqc:xns($parts,$ret){
    xqc:block(subsequence($parts,4),concat($ret, "core:namespace($,",$parts[1],",",$parts[3],")"))
};

declare function xqc:annot($parts,$ret,$annot){
	let $maybe-annot := head($parts)/fn:group[@nr=1]/string()
	let $rest := tail($parts)
	return
		if(matches($maybe-annot,"^%")) then
			xqc:annot($rest,$ret,replace($maybe-annot,"^%","-"))
		else if($maybe-annot = "namespace") then
		    xqc:xns($rest,$ret)
		else if($maybe-annot = "=#2106=") then
			xqc:xfn($rest,concat($ret, "core:define", $annot, "($,"))
		else if($maybe-annot = "=#218=") then
			xqc:xvar($rest,concat($ret, "core:xvar",$annot, "($,"))
		else $ret
};

declare function xqc:xversion($parts,$ret){
	xqc:block(subsequence($parts,3),concat($ret,"core:xq-version($,",$parts[2]/string(),")"))
};

declare function xqc:xmodule($parts,$ret){
	xqc:block(subsequence($parts,5),concat($ret,"core:module($,",$parts[2]/string(),",",$parts[4]/string(),",())"))
};

declare function xqc:close($lastseen, $no as xs:integer){
    array:reverse(xqc:close($lastseen, $no, [], array:size($lastseen)))
};

declare function xqc:close($lastseen,$no as xs:integer, $ret, $s){
    if($no eq 0 or $s eq 0) then
		array:join(($ret,array:reverse($lastseen)))
	else
	    let $last := array:get($lastseen,$s)
        return
	        if($last eq 40) then
                xqc:close(array:remove($lastseen,$s),$no - 1,$ret, $s - 1)
            else
                xqc:close(array:remove($lastseen,$s),$no, array:append($ret,$last),$s - 1)
};

declare function xqc:closer($b,$c as xs:integer){
	if(array:size($b) gt 0 and a:last($b) = (208,211)) then
		xqc:closer(a:pop($b),$c + 1)
	else
		$c
};

declare function xqc:filter($a,$b) {
    array:filter($a,function($x) { $x = $b })
};

declare function xqc:repeat-string($a,$b) {
    string-join((1 to $a) ! $b)
};

declare function xqc:anon($head,$parts,$ret,$lastseen) {
	xqc:params($parts,concat($ret, "core:anon($,("),$lastseen)
};

declare function xqc:comment($parts,$ret,$lastseen) {
	let $head := head($parts)/string()
	let $rest := tail($parts)
	return
		if($head = "=#2502=") then
			xqc:body($rest,$ret,$lastseen)
		else
			xqc:comment($rest,$ret,$lastseen)
};

declare function xqc:detect-group-by($parts) {
    let $head := head($parts)/string()
    return
        if($head eq "=#223=") then
            true()
        else if($head eq "=#211=" or empty($parts)) then
            false()
        else
            xqc:detect-group-by(tail($parts))
};

declare function xqc:op-let($rest,$ret,$lastseen,$llast,$temp) {
    if($llast eq 222) then
        let $lastseen := array:append(array:append(a:pop($lastseen),2107),2006)
        return xqc:op-let($rest,concat(
            $ret,
            "=#1800=",
            "core:anon($,(",a:last($temp),"),core:item()*,"),$lastseen,2006,a:pop($temp))
    else
    let $hascomma := $llast eq 207 or ($llast eq 208 and matches($ret,",$"))
	let $letopener :=
		not($llast = (209,210) or ($llast eq 208 and $hascomma = false())) or
		$llast eq 2006
	let $letclose := not($llast eq 2006 or array:size($lastseen) eq 0) and $hascomma eq false()
	let $letcloser :=
		if($letclose and $llast = (208,211,1901)) then
			xqc:closer($lastseen,0)
		else
			0
	let $last := array:size($lastseen) - $letcloser
	let $ret :=
		concat(
		    $ret,
			if($letclose) then
				concat(
					xqc:repeat-string($letcloser,")"),
					if(array:get($lastseen,$last) eq 210) then ")" else "",
					if($hascomma) then "" else ","
				)
			else "",
			if($letopener) then "(" else "",
			"=#209=",
		    concat("($,",replace(head($rest)/string(),"^\$|\s",""))
		)
	let $lastseen :=
		if($letclose) then
			array:subarray($lastseen,1,$last)
		else
			$lastseen
	let $lastseen := if($letclose and a:last($lastseen) eq 210) then a:pop($lastseen) else $lastseen
	return xqc:body(tail($rest), $ret, array:append($lastseen,209),$temp)
};

declare function xqc:op-comma($rest,$ret,$lastseen) {
    (: FIXME dont close a sequence :)
	(: FIXME add check for nested last :)
	let $closer := xqc:closer($lastseen,0)
	let $s := array:size($lastseen)
	let $lastseen := array:subarray($lastseen,1, $s - $closer)
	let $ret :=
		concat(
			$ret,
			xqc:repeat-string($closer,")"),
			if(array:get($lastseen,$s - 1) eq 2107) then
			    "),=#2701=("
			else
			    ","
		)
	return xqc:body($rest,$ret,$lastseen)
};

declare function xqc:op-close-curly($rest,$ret,$lastseen,$llast,$temp) {
	let $lastindex := a:last-index-of($lastseen,2006)
	let $closes := xqc:filter(array:subarray($lastseen,$lastindex + 1),(208,211))
	(: add one extra closed paren by consing 211 :)
	let $reopen := head($rest)/string() eq "=#2006="
	let $closes := if($reopen) then $closes else array:append($closes,211)
	(: eat up until 2006 :)
	let $lastseen := array:subarray($lastseen,1,$lastindex - 1)
	let $llast := a:last($lastseen)
	(: close the opening type UNLESS its another opener :)
	(: ALT leave JSON intact :)
	let $ret := concat(
	    $ret,
	    if($llast idiv 100 eq 21) then
	        ")"
		else
			"",
		if(($llast eq 2107 or empty($llast)) and matches($ret,"\($") = false()) then
			")"
		else
		    "",
		xqc:repeat-string(array:size($closes),")"),
		if($reopen) then
			","
		else
		    ""
	)
	(: remove opening type UNLESS next is another opener :)
	let $lastseen := if($llast idiv 100 eq 21 and $reopen) then $lastseen else a:pop($lastseen)
	return xqc:body($rest,$ret,$lastseen,$temp)
};

declare function xqc:op-constructor($no,$rest,$ret,$lastseen) {
    let $ret := concat($ret,xqc:op-str($no),"(")
	let $next := head($rest)/string()
	(: for element etc, check if followed by qname :)
	let $qn := if($next ne "=#2006=") then $next else ()
	let $rest :=
		if(exists($qn)) then
			tail($rest)
		else
			$rest
	let $ret :=
		if(exists($qn)) then
			concat($ret,$next,",")
		else
			$ret
	return xqc:body($rest,$ret,array:append($lastseen,$no))
};

declare function xqc:op-then($rest,$ret,$lastseen,$llast,$temp){
    let $ret := concat(
	    $ret,
		if($llast eq 211) then ")" else "",
		","
	)
	(: if then expect an opener and remove it :)
	let $lastseen :=
		if($llast eq 211 or $llast eq 40) then
			a:pop($lastseen)
		else
			$lastseen
	let $last := a:last-index-of($lastseen,206)
	let $lastseen := if($last gt 0) then array:append(array:remove($lastseen,$last),207) else $lastseen
	return xqc:body($rest,$ret,$lastseen,$temp)
};

declare function xqc:op-assign($rest,$ret,$lastseen,$llast,$temp){
    if(array:get($lastseen,array:size($lastseen) - 1) eq 2107) then
        xqc:body($rest, concat($ret,","), $lastseen)
    else
    let $ret := concat(
	    $ret,
		if($llast eq 211) then ")" else "",
		","
	)
	(: if then expect an opener and remove it :)
	let $lastseen :=
		if($llast eq 211) then
			a:pop($lastseen)
		else
			$lastseen
	let $last := a:last-index-of($lastseen,209)
	let $lastseen := if($last gt 0) then array:append(array:remove($lastseen,$last),210) else $lastseen
	return xqc:body($rest,$ret,$lastseen,$temp)
};

declare function xqc:op-else($rest,$ret,$lastseen,$llast,$temp){
    let $closer := a:last-index-of($lastseen, 207)
    let $ret :=
		concat(
		    $ret,
			xqc:repeat-string(array:size($lastseen) - $closer,")"),
			","
		)
	let $lastseen := array:subarray($lastseen, 1, $closer - 1)
    return xqc:body($rest,$ret,array:append($lastseen,208),$temp)
};

declare function xqc:op-return($rest,$ret,$lastseen,$llast,$temp){
    if($llast eq 222) then
        xqc:body($rest,concat($ret,"=#1800=core:anon($,(",a:last($temp),"),core:item()*,("),array:append(array:append(a:pop($lastseen),211),211),a:pop($temp))
    else
        let $closer := a:last-index-of($lastseen, 210)
        let $ret :=
    		concat(
    		    $ret,
    			xqc:repeat-string(array:size($lastseen) - $closer,")"),
    			"),"
    		)
    	let $lastseen := array:subarray($lastseen, 1, $closer - 1)
        return xqc:body($rest,$ret,array:append($lastseen,211))
};

declare function xqc:op-close-square($rest,$ret,$lastseen,$llast,$temp) {
    let $ret := concat($ret,
        if($llast = (1901,2004) or ($llast eq 2001 and array:get($lastseen,array:size($lastseen) - 1) eq 1901)) then
            "))"
        else
            ")")
    let $lastseen :=
        if($llast = 1901 or ($llast eq 2001 and array:get($lastseen,array:size($lastseen) - 1) eq 1901)) then
            a:pop(a:pop($lastseen))
        else
    	    a:pop($lastseen)
	return xqc:body($rest,$ret,$lastseen,$temp)
};

declare function xqc:op-open-square($no,$rest,$ret,$lastseen){
    let $ret :=
		concat(
		    $ret,
			xqc:op-str($no),
			if($no eq 2004) then "((" else "("
		)
	return xqc:body($rest, $ret, array:append($lastseen,$no))
};

declare function xqc:op-open-curly($rest,$ret,$lastseen,$llast){
    (: ALT leave JSON literal as-is :)
    let $ret := concat($ret,
	    if($llast eq 2107 or $llast idiv 100 ne 21) then
	        let $next := head($rest)/string()
	        return if(empty($next) or $next eq "=#2007=") then "(" else "(=#2701=("
        else
            "(")
    return xqc:body($rest,$ret,array:append($lastseen,2006))
};

declare function xqc:op-select($rest,$ret,$lastseen,$llast,$temp) {
    let $ret := concat($ret,if($llast eq 1901) then "," else "=#1901=(")
    let $lastseen := if($llast = 1901) then $lastseen else array:append($lastseen,1901)
    return xqc:body($rest,$ret,$lastseen,$temp)
};

declare function xqc:op-for($rest,$ret,$lastseen,$llast,$temp) {
    xqc:body($rest,$ret,array:append($lastseen,221),$temp)
};

declare function xqc:op-in($rest,$ret,$lastseen,$llast,$temp) {
    xqc:body($rest,$ret,array:append(a:pop($lastseen),222),$temp)
};

declare function xqc:body-op($no,$rest,$ret as xs:string,$lastseen,$temp){
	let $llast := a:last($lastseen)
	(: FIXME add check for nested last :)
	let $has-filter := $llast eq 1901
	let $ret := concat($ret,
	    if($has-filter) then
		    if($no eq 2001) then
		        ","
		    else
		        ")"
		else
		    "")
	let $lastseen :=
	    if($has-filter) then
	        if($no eq 2001) then
	            $lastseen
	        else
	            a:pop($lastseen)
	    else
	        $lastseen
	let $llast := if($has-filter) then a:last($lastseen) else $llast
	return
        if($no eq 1) then
    		xqc:op-comma($rest,$ret,$lastseen)
    	else if($no eq 206) then
    		xqc:body($rest, concat($ret, xqc:op-str($no)), array:append($lastseen,$no))
    	else if($no eq 207) then
    		xqc:op-then($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 208) then
    	    xqc:op-else($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 209) then
            xqc:op-let($rest,$ret,$lastseen,$llast,$temp)
        else if($no = 210) then
    		xqc:op-assign($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 211) then
    	    xqc:op-return($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 221) then
    	    xqc:op-for($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 222) then
    		xqc:op-in($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 1901) then
    	    xqc:op-select($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 2007) then
    	    xqc:op-close-curly($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 2002) then
    	    xqc:op-close-square($rest,$ret,$lastseen,$llast,$temp)
    	else if($no eq 2006) then
            xqc:op-open-curly($rest,$ret,$lastseen,$llast)
        else if($no eq 2106) then
    		xqc:anon(head($rest)/string(),tail($rest),$ret,$lastseen)
    	else if($no eq 2501) then
    		xqc:comment($rest,$ret,$lastseen)
    	else if($no eq 2600) then
    		xqc:body($rest, concat($ret,","), $lastseen)
    	else if($no idiv 100 eq 21) then
    		xqc:op-constructor($no,$rest,$ret,$lastseen)
    	else if($no = (2001,2004)) then
    		xqc:op-open-square($no,$rest,$ret,$lastseen)
    	else
            xqc:body($rest,concat($ret,xqc:op-str($no)),$lastseen,$temp)
};

declare function xqc:paren-closer($head,$lastseen){
	if(matches($head,"[\(\)]+")) then
	    let $cp := string-to-codepoints($head)
		let $lastseen := fold-left($cp[. eq 40],$lastseen,function($pre,$cur){
		    array:append($pre,$cur)
		})
		return
	        xqc:close($lastseen,count($cp[. eq 41]))
	else
		$lastseen
};


declare function xqc:body($parts,$ret) {
    xqc:body($parts,$ret,[])
};

declare function xqc:body($parts,$ret,$lastseen) {
    xqc:body($parts,$ret,$lastseen,[])
};

declare function xqc:body($parts,$ret,$lastseen,$temp){
	if(empty($parts)) then
		concat($ret, xqc:repeat-string(array:size(xqc:filter($lastseen,(208,211,2007,218,1901))), ")"))
	else
		let $head := head($parts)/string()
		let $rest := tail($parts)
		let $llast := a:last($lastseen)
		let $lastseen := if($llast eq 0) then a:pop($lastseen) else $lastseen
		let $lastseen := xqc:paren-closer($head,$lastseen)
		return
			if($head = "=#2501=") then
				xqc:comment($rest,$ret,$lastseen)
			else if(matches($head,";")) then
				xqc:block($parts, $ret)
			else
				let $rest :=
					if($head = $xqc:fns) then
					    let $next := head($rest)/string() return
					    if(matches($next,"[^\.]\)")) then
    						insert-before(tail($rest),1,element fn:match {
    							element fn:group {
    								attribute nr { 1 },
    								replace($next,"^([^\)]*)\)","$1.)")
    							}
    						})
    					else
    					    $rest
					else
						$rest
				(: array if there was nothing before... :)
				let $head :=
					if($head eq "=#2001=" and $llast ne 0) then
						"=#2004="
					else
						$head
				return
					if(matches($head,$xqc:operator-regexp)) then
						xqc:body-op(xqc:op-num($head),$rest,$ret,$lastseen,$temp)
					else
				        if($llast eq 221) then
				            xqc:body($rest,$ret,$lastseen,array:append($temp,$head))
				        else
						    xqc:body($rest,concat($ret,$head),if(matches($head,"\(")) then $lastseen else array:append($lastseen,0),$temp)
};

declare function xqc:ximport($parts,$ret) {
	let $rest := subsequence($parts,6)
	let $maybe-at := head($rest)/string()
	return
		if(matches($maybe-at,"at")) then
			xqc:block(subsequence($rest,3),concat($ret,"core:ximport($,",$parts[3]/string(),",",$parts[5]/string(),",",$rest[2]/string(),")"))
		else
			xqc:block($rest,concat($ret,"core:ximport($,",$parts[3]/string(),",",$parts[5]/string(),")"))
};

declare function xqc:block($parts,$ret){
	if(empty($parts)) then
		$ret
	else
		let $val := head($parts)/string()
		return
			if(matches($val,$xqc:operator-regexp)) then
				let $no := xqc:op-num($val)
				return
					if($no eq 214) then
						xqc:xversion(tail($parts),$ret)
					else if($no eq 216) then
						xqc:xmodule(tail($parts),$ret)
					else if($no eq 217) then
						xqc:annot(tail($parts),$ret,"")
					else if($no eq 219) then
						xqc:ximport(tail($parts),$ret)
					else
						xqc:body($parts,$ret)
			else
				xqc:body($parts,$ret)
};


declare function xqc:to-op($opnum,$params){
	if(map:contains($params("$operator-map"),$opnum)) then
		concat("core:",$params("$operator-map")($opnum))
	else
		concat("core:",replace($params("$operators")($opnum)," ","-"))
};

declare function xqc:escape-for-regex($key,$params) as xs:string {
	let $arg := $params("$operators")($key)
	let $pre := "(^|[\s,\(\);\[\]]+)"
	return
		if(matches($arg,"\p{L}+")) then
			if($key eq 217) then
			    "(\s?|;?)" || $arg || "(\s?)"
			else if($key eq 2106) then
				$pre || $arg || "([\s" || $xqc:ncname || ":]*\s*\((\$|\)))"
			else if($key idiv 100 eq 21) then
				$pre || $arg || "([\s\$" || $xqc:ncname || ",:]*=#2006)"
			else if($key eq 204 or $key idiv 100 eq 22) then
				$pre || $arg || "(\()"
			else if($key idiv 100 eq 24) then
				$pre || $arg || "(\s)"
			else if($arg = "if") then
				$pre || $arg || "(\s?)"
			else if($arg = "then") then
				"\)(\s*)" || $arg || "(\s?)"
			else
				"(^|\s)" || $arg || "(\s|$)"
		else
			let $arg := replace($arg,"(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))","\\$1")
			return
				if($key eq 210) then
					"(\s?):\s*=([^#])"
(:				else if($key eq 2003) then:)
(:					"(\s?)" || $arg || "(\s*[" || $xqc:ncname || "\(]+)":)
				else if($key eq 2600) then
					"(\s?)" || $arg || "([^=]\s*[^\p{L}_])"
				else if($key = (802,1702)) then
					"(^|\s|[^\p{L}\p{N}]\p{N}+|[\(\)\.,])" || $arg || "([\s\p{N}])?"
				else if($key = (801,901,2003)) then
					"([^/])" || $arg || "(\s*[^,\)\{])"
				else
					"(\s?)" || $arg || "(\s?)"
};

declare function xqc:unary-op($op){
	if($op idiv 100 eq 17) then $op else $op + 900
};

declare function xqc:op-num($op) as xs:decimal {
	if($op ne "") then
	    xs:integer(replace($op,"^=#(\p{N}+)=$","$1"))
	else
	    0
};

declare function xqc:op-str($op){
	concat("=#",string($op),"=")
};

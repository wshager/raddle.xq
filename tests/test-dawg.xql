xquery version "3.1";

import module namespace dawg="http://lagua.nl/dawg" at "/db/apps/raddle.xq/lib/dawg.xql";

let $ops := map {
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
	2201: "array(",
	2202: "attribute(",
	2203: "comment(",
	2204: "document-node(",
	2205: "element(",
	2206: "empty-sequence(",
	2208: "item(",
	2209: "map(",
	2210: "namespace-node",
	2211: "node",
	2212: "processing-instruction(",
	2213: "schema-attribute",
	2214: "schema-element",
	2215: "text(",
	2400: "as",
	2501: "(:",
	2502: ":)",
	2600: ":"
}
let $dawg := map {
	"!": [map {
		"_k": "!",
		"_v": 1800
	}, map {
		"=": map {
			"_k": "!=",
			"_v": 508
		}
	}],
	"(": map {
		"_k": "(:",
		"_v": 2501
	},
	"*": map {
		"_k": "*",
		"_v": 901
	},
	"+": map {
		"_k": "+",
		"_v": 801
	},
	"-": map {
		"_k": "-",
		"_v": 802
	},
	"/": map {
		"_k": "/",
		"_v": 1901
	},
	":": [map {
		"_k": ":",
		"_v": 2600
	}, map {
		")": map {
			"_k": ":)",
			"_v": 2502
		}
	}, map {
		"=": map {
			"_k": ":=",
			"_v": 210
		}
	}],
	"<": [map {
		"_k": "<",
		"_v": 513
	}, map {
		"<": map {
			"_k": "<<",
			"_v": 511
		}
	}, map {
		"=": map {
			"_k": "<=",
			"_v": 509
		}
	}],
	"=": [map {
		"_k": "=",
		"_v": 507
	}, map {
		">": map {
			"_k": "=>",
			"_v": 1600
		}
	}],
	">": [map {
		"_k": ">",
		"_v": 514
	}, map {
		"=": map {
			"_k": ">=",
			"_v": 510
		}
	}, map {
		">": map {
			"_k": ">>",
			"_v": 512
		}
	}],
	"?": map {
		"_k": "?",
		"_v": 2003
	},
	"a": [map {
		"_k": "and",
		"_v": 400
	}, map {
		"r": [map {
			"_k": "array",
			"_v": 2101
		}, map {
			"r": map {
				"_k": "array(",
				"_v": 2201
			}
		}]
	}, map {
		"s": map {
			"_k": "as",
			"_v": 2400
		}
	}, map {
		"t": [map {
			"_k": "at",
			"_v": 220
		}, map {
			"t": [map {
				"_k": "attribute",
				"_v": 2102
			}, map {
				"r": map {
					"_k": "attribute(",
					"_v": 2202
				}
			}]
		}]
	}],
	"c": [map {
		"_k": "case",
		"_v": 212
	}, map {
		"a": [map {
			"_k": "cast as",
			"_v": 1500
		}, map {
			"s": map {
				"_k": "castable as",
				"_v": 1400
			}
		}]
	}, map {
		"o": [map {
			"_k": "comment",
			"_v": 2103
		}, map {
			"m": map {
				"_k": "comment(",
				"_v": 2203
			}
		}]
	}],
	"d": [map {
		"_k": "declare",
		"_v": 217
	}, map {
		"e": map {
			"_k": "default",
			"_v": 213
		}
	}, map {
		"i": map {
			"_k": "div",
			"_v": 903
		}
	}, map {
		"o": [map {
			"_k": "document",
			"_v": 2104
		}, map {
			"c": map {
				"_k": "document-node(",
				"_v": 2204
			}
		}]
	}],
	"e": [map {
		"_k": "element",
		"_v": 2105
	}, map {
		"l": [map {
			"_k": "element(",
			"_v": 2205
		}, map {
			"s": map {
				"_k": "else",
				"_v": 208
			}
		}]
	}, map {
		"m": map {
			"_k": "empty-sequence(",
			"_v": 2206
		}
	}, map {
		"q": map {
			"_k": "eq",
			"_v": 501
		}
	}, map {
		"v": map {
			"_k": "every",
			"_v": 202
		}
	}, map {
		"x": map {
			"_k": "except",
			"_v": 1102
		}
	}],
	"f": [map {
		"_k": "for",
		"_v": 221
	}, map {
		"u": map {
			"_k": "function",
			"_v": 2106
		}
	}],
	"g": [map {
		"_k": "ge",
		"_v": 506
	}, map {
		"r": map {
			"_k": "group by",
			"_v": 223
		}
	}, map {
		"t": map {
			"_k": "gt",
			"_v": 505
		}
	}],
	"i": [map {
		"_k": "idiv",
		"_v": 902
	}, map {
		"f": map {
			"_k": "if",
			"_v": 206
		}
	}, map {
		"m": map {
			"_k": "import",
			"_v": 219
		}
	}, map {
		"n": [map {
			"_k": "in",
			"_v": 222
		}, map {
			"s": map {
				"_k": "instance of",
				"_v": 1200
			}
		}, map {
			"t": map {
				"_k": "intersect",
				"_v": 1101
			}
		}]
	}, map {
		"s": map {
			"_k": "is",
			"_v": 515
		}
	}, map {
		"t": map {
			"_k": "item(",
			"_v": 2208
		}
	}],
	"l": [map {
		"_k": "le",
		"_v": 504
	}, map {
		"e": map {
			"_k": "let",
			"_v": 209
		}
	}, map {
		"t": map {
			"_k": "lt",
			"_v": 503
		}
	}],
	"m": [map {
		"_k": "map",
		"_v": 2107
	}, map {
		"a": map {
			"_k": "map(",
			"_v": 2209
		}
	}, map {
		"o": [map {
			"_k": "mod",
			"_v": 904
		}, map {
			"d": [map {
				"_k": "module",
				"_v": 216
			}]
		}]
	}],
	"n": [map {
		"_k": "namespace",
		"_v": 2108
	}, map {
		"a": map {
			"_k": "namespace-node",
			"_v": 2210
		}
	}, map {
		"e": map {
			"_k": "ne",
			"_v": 502
		}
	}, map {
		"o": map {
			"_k": "node",
			"_v": 2211
		}
	}],
	"o": map {
		"_k": "or",
		"_v": 300
	},
	"p": [map {
		"_k": "processing-instruction",
		"_v": 2109
	}, map {
		"r": map {
			"_k": "processing-instruction(",
			"_v": 2212
		}
	}],
	"r": map {
		"_k": "return",
		"_v": 211
	},
	"s": [map {
		"_k": "schema-attribute",
		"_v": 2213
	}, map {
		"c": map {
			"_k": "schema-element",
			"_v": 2214
		}
	}, map {
		"o": map {
			"_k": "some",
			"_v": 201
		}
	}, map {
		"w": map {
			"_k": "switch",
			"_v": 203
		}
	}],
	"t": [map {
		"_k": "text",
		"_v": 2110
	}, map {
		"e": map {
			"_k": "text(",
			"_v": 2215
		}
	}, map {
		"h": map {
			"_k": "then",
			"_v": 207
		}
	}, map {
		"o": map {
			"_k": "to",
			"_v": 700
		}
	}, map {
		"r": [map {
			"_k": "treat as",
			"_v": 1300
		}, map {
			"y": map {
				"_k": "try",
				"_v": 205
			}
		}]
	}, map {
		"y": map {
			"_k": "typeswitch",
			"_v": 204
		}
	}],
	"u": map {
		"_k": "union",
		"_v": 1001
	},
	"v": [map {
		"_k": "variable",
		"_v": 218
	}, map {
		"e": map {
			"_k": "version",
			"_v": 215
		}
	}],
	"x": map {
		"_k": "xquery",
		"_v": 214
	},
	"|": [map {
		"_k": "|",
		"_v": 1002
	}, map {
		"|": map {
			"_k": "||",
			"_v": 600
		}
	}]
}


return dawg:traverse([$dawg,[]],"=")
(:return map:for-each-entry($ops,function($k,$v){:)
(:    [$k,dawg:traverse([$dawg],$v)]:)
(:}):)
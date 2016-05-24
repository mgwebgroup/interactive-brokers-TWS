BEGIN {
  cacheFileName = "cache.tmp"
  fileNameForInputMap = "map.old"
  fileNameForOutputMap = "map.new"
  columnDelimeter = "COLUMN,[0-9]+"
  sectorDelimeter = "HED,[A-Z]+"
  categoryDelimeter = "(HED,MOVER|HED,STRENGTH|HED,ID|HED,WEAKNESS|HED,ACTION_EXPECTED)"
  
  linesInInputMapPerSector = 6
  linesInOutputMapPerSector = linesInInputMapPerSector
  sectorOrderInInputMap = trimRegExDelimetersInString( "XLF,XLE,XLK,XLI,XLV,XLP,XRT,XLB,XTL,XLU,XLY,XHB", "," )
  sectorOrderInOutputMap = trimRegExDelimetersInString( "XLF,XLE,XLK,XLI,XLV,XLP,XRT,XLB,XTL,XLU,XLY,XHB", "," )
  sectorTotal = split( sectorOrderInInputMap, sectorOrderInByNum )
  if ( split( sectorOrderInOutputMap, sectorOrderOutByNum ) != sectorTotal ) { 
    warningPrintedAtEnd[1] = "Number of elements in sectorOrderInInputMap needs to match number of elements in sectorOrderInOutputMap. Check BEGIN section of the program."
    split( sectorOrderInInputMap, sectorOrderOutByNum )
  }
  #arrayFlip( sectorOrderInByNum, sectorOrderInByName )
  #arrayFlip( sectorOrderOutByNum, sectorOrderOutByName )

  categoryList = trimRegExDelimetersInString( "MOVER,STRENGTH,ID,WEAKNESS,ACTION_EXPECTED,ACTION_EXPECTED", "," )
  columnsTotal = split( categoryList, categoryByColumnNumber, "," )

#Actions superimposed onto opcodes. The format is: action[<exec_order>]="<CODE_NAME>,<CATEGORY>,<opcode>".
# <CODE_NAME>: -1 EXCLUDE, 1 INCLUDE, 2 MOVER, -2 ID, 100 STRENGTH, -100 WEAKNESS. These are put into the spreadsheet.
# <CATEGORY>: is column name in the market map in TWS.
# <opcode>: Function within this program that does stuff (most of them are sed commands)
  actionsOrder = "EXCLUDE,MOVER,delete;EXCLUDE,STRENGTH,delete;EXCLUDE,ID,delete;EXCLUDE,WEAKNESS,delete;EXCLUDE,ACTION_EXPECTED,delete;"
  actionsOrder = actionsOrder "INCLUDE,STRENGTH,delete;INCLUDE,ID,delete;INCLUDE,WEAKNESS,delete;INCLUDE,ACTION_EXPECTED,delete;INCLUDE,ACTION_EXPECTED,add;"
  actionsOrder = actionsOrder "STRENGTH,MOVER,delete;STRENGTH,STRENGTH,delete;STRENGTH,ID,delete;STRENGTH,WEAKNESS,delete;STRENGTH,ACTION_EXPECTED,delete;STRENGTH,STRENGTH,add;"
  actionsOrder = actionsOrder "WEAKNESS,MOVER,delete;WEAKNESS,STRENGTH,delete;WEAKNESS,ID,delete;WEAKNESS,WEAKNESS,delete;WEAKNESS,ACTION_EXPECTED,delete;WEAKNESS,WEAKNESS,add;"
  actionsOrder = actionsOrder "MOVER,ACTION_EXPECTED,delete;MOVER,ID,delete;MOVER,MOVER,delete;MOVER,MOVER,add;"
  actionsOrder = trimRegExDelimetersInString( actionsOrder, ";" )
  actionsTotal = split( actionsOrder, action, ";" )

  textMap = loadTextVarFromFile( fileNameForInputMap )
  textMap = trimRegExDelimetersInString( textMap, columnDelimeter )
  #print textMap; exit
  
  createCategorySectorMap( textMap )
  
} 
# end of BEGIN section

$(col) == -1 { list[$5,"EXCLUDE"] = list[$5,"EXCLUDE"] $1 "," }
$(col) == 1 { list[$5,"INCLUDE"] = list[$5,"INCLUDE"] $1 "," }
$(col) == -2 { list[$5,"ID"] = list[$5,"ID"] $1 "," }
$(col) == 2 { list[$5,"MOVER"] = list[$5,"MOVER"] $1 "," }
$(col) == 100 { list[$5,"STRENGTH"] = list[$5,"STRENGTH"] $1 "," }
$(col) == -100 { list[$5,"WEAKNESS"] = list[$5,"WEAKNESS"] $1 "," }


END {

  for ( i = 1; i <= actionsTotal; i++ ) {
    split( action[i], data )
    codeName = data[1]
    categoryName = data[2]
    opCode = data[3]
    # print "codeName=" codeName " category=" categoryName " opCode=" opCode "\n"
    for ( j = 1; j <= sectorTotal; j++ ) {
      sectorName = sectorOrderInByNum[j]
      if ( (sectorName,codeName) in list ) {
        symbolsList = trimRegExDelimetersInString( list[sectorName,codeName], "," )
        postPosition = createPostPositionForWord( opCode )
        printf( "Code=%s Sector=%s Symbols:%s %s %s %s\n", codeName, sectorName, symbolsList, opCode, postPosition, categoryName )
        dumpStringToFile( categorySectorMap[categoryName,sectorName], cacheFileName )
        #print "inital symbols group: \n" categorySectorMap[categoryName,sectorName] "\n"
        command = ""
        totalSymbols = split( symbolsList, symbol )
        for ( k = 1; k <= totalSymbols; k++ ) {
          if ( "delete" == opCode ) command = command "sed -i -r \"s-DES," symbol[k] ",STK,[[:alpha:]]*/?[[:alpha:]]*,,,,,--g\" " cacheFileName ";"
          if ( "add" == opCode ) command = command "sed -i \"1s-^-DES," symbol[k] ",STK,SMART/NYSE,,,,,\\n-\" " cacheFileName ";"
        }
        system( command )
        categorySectorMap[categoryName,sectorName] = loadTextVarFromFile( cacheFileName ) "\n"
        #print "processed symbols group: \n" categorySectorMap[categoryName,sectorName] "\n"

      }
    }
  }

  #print "---creating textMap---\n"
  textMap = ""
  command = "cat " cacheFileName " | sed -n \"1p\"; sed -i -n \"1d;p\" " cacheFileName
  #print command; exit
  for ( i = 1; i <= columnsTotal; i++ ) {
    categoryName = categoryByColumnNumber[i]
    textMap = textMap "COLUMN," i - 1 "\n"
    textMap = textMap "HED," categoryName "\n"
    for ( j = 1; j <= sectorTotal; j++ ) {
      sectorName = sectorOrderOutByNum[j]
      textMap = textMap "HED," sectorName "\n"
      categorySectorMap[categoryName,sectorName] = deleteEmptyLines( categorySectorMap[categoryName,sectorName] )
      #print "COLUMN," i - 1 " category=" categoryName " symbols group after compressing empty lines in sector " sectorName ":\n" categorySectorMap[categoryName,sectorName] "\n"
      dumpStringToFile( categorySectorMap[categoryName,sectorName], cacheFileName )
      for ( k = 1; k <= linesInOutputMapPerSector; k++ ) {
        line = ""
        command | getline line
        close( command )
        #print "command=" command " k=" k " line=" line "\n"
        textMap = textMap line "\n"
      }
      categorySectorMap[categoryName,sectorName] = loadTextVarFromFile( cacheFileName )
      #print "symbols group after sed command: " categorySectorMap[categoryName,sectorName] "\n"
    }


  }

  print textMap > fileNameForOutputMap

  printWarnings()

}
# END

function printWarnings() {
  for ( i in warningPrintedAtEnd ) {
    print warningPrintedAtEnd[i] "\n"
  }

}

function dumpStringToFile( aString, fileName ) {
  print aString > fileName
  close( fileName )
}

function loadTextVarFromFile( fileName ) {
  textVar = ""; line = ""
  while ( ( getline line < fileName ) > 0 ) {
    textVar = textVar line "\n"
    #textVar = textVar line
  }
  close( fileName )
  # remove last "\n" at End Of String
  line = substr(textVar, 1, length( textVar ) - 1 ) 
  return line
  #return textVar
}

#removes excess delimiters in the beginnig and end of string, for example in: ",XLF,XLE,XLK,XLI,XLV,XLP,XRT,XLB,XTL,XLU,XLY,XHB," leading and trailing commas would be removed
function trimRegExDelimetersInString( stringIn, regExDelimeter ) {
  if ( gsub( "\n", "@", stringIn ) ) regExDelimeter = regExDelimeter "@"
  dumpStringToFile( stringIn, cacheFileName ) 
  tREDIS_command = "sed -i -r \"s/^" regExDelimeter "//\" " cacheFileName
  system( tREDIS_command )
  tREDIS_command = "sed -i -r \"s/" regExDelimeter "$//\" " cacheFileName
  system( tREDIS_command )
  stringIn = loadTextVarFromFile( cacheFileName )
  gsub( "@", "\n", stringIn )
  return stringIn
}

# creates array columnSectorMap[int <column_number>,sting <sector_name>] and compress empty lines
function createColumnSectorMap( textMap ) {
  split( textMap, column, columnDelimeter "\n" )
  for ( i = 1; i <= columnsTotal; i++ ) {
    column[i] = trimRegExDelimetersInString( column[i], categoryDelimeter )
    column[i] = trimRegExDelimetersInString( column[i], sectorDelimeter )
    split( column[i], sectorSymbols, sectorDelimeter "\n" )
    #print "column=" i ": \n"
    for ( j = 1; j <= sectorTotal; j++ ) {
      sectorName = sectorOrderInByNum[j]
      #print "sector=" sectorName ":\n"
      #print sectorSymbols[j] "\n"
      compressedSectorSymbols = deleteEmptyLines( sectorSymbols[j] )
      #print "compressed:\n" compressedSectorSymbols
      columnSectorMap[i,sectorName] = compressedSectorSymbols
      #print columnSectorMap[i,sectorName]
    }
  }
}

# creates array categorySectorMap(string <category>, string <sector>). Combines sector symbols for same category that may hold several columns into one list
function createCategorySectorMap( textMap ) {
  createColumnSectorMap( textMap )
  for ( i = 1; i <= columnsTotal; i++ ) {
    categoryName = categoryByColumnNumber[i]
    #print categoryName "\n"
    for ( j = 1; j <= sectorTotal; j++ ) {
      sectorName = sectorOrderInByNum[j]
      #print "sector=" sectorName ":\n"
      categorySectorMap[categoryName,sectorName] = categorySectorMap[categoryName,sectorName] columnSectorMap[i,sectorName]
      #print categorySectorMap[categoryName,sectorName]
    }
  }
}

function deleteEmptyLines( stringIn ) {
  stringOut = ""
  dumpStringToFile( stringIn, cacheFileName )
  dEL_command = "grep -E \"^DES,[[:alpha:]]+,STK,[[:alpha:]]*/?[[:alpha:]]*,,,,,\" " cacheFileName
  while ( ( dEL_command | getline line ) > 0 ) stringOut = stringOut line "\n"
  close(dEL_command)
  return stringOut
}

function createPostPositionForWord( word ) {
  postPosition = ""
  if ( word == "delete" ) postPosition = "from"
  if ( word == "add" ) postPosition = "to"
  return postPosition
}


#-----------------------------------------------#
# Functions that are not used

# function arrayFlip( arrayIn, arrayOut ) {
#   for ( i in arrayIn ) {
#     arrayOut[arrayIn[i]] = i
#   }
# }

#ftest for function padStringToNumberOfLines( stringIn, n ):
#print padStringToNumberOfLines( "DES,BHI,STK,SMART/NYSE,,,,,\n", 2 )
# //n = 1; DES,BHI,STK,SMART/NYSE,,,,,@    output: DES,BHI,STK,SMART/NYSE,,,,,@ 
# //n = 1; DES,BHI,STK,SMART/NYSE,,,,,     output: DES,BHI,STK,SMART/NYSE,,,,, 
# //n = 1; <empty>                         output: @ 
# //n = 1; DES,BHI,STK,SMART/NYSE,,,,,@@   output: DES,BHI,STK,SMART/NYSE,,,,,@@ 

# //n = 2; DES,BHI,STK,SMART/NYSE,,,,,@    output: DES,BHI,STK,SMART/NYSE,,,,,@@ 
# //n = 2; DES,BHI,STK,SMART/NYSE,,,,,     output: DES,BHI,STK,SMART/NYSE,,,,,@@ 
# //n = 2; <empty>                         output: @@ 
# //n = 2; DES,BHI,STK,SMART/NYSE,,,,,@@   output: DES,BHI,STK,SMART/NYSE,,,,,@@ 
# //n = 2; DES,BHI,STK,SMART/NYSE,,,,,@@@  output: DES,BHI,STK,SMART/NYSE,,,,,@@@ 
#tcode:
  # listStringIn = ";DES,BHI,STK,SMART/NYSE,,,,,;DES,BHI,STK,SMART/NYSE,,,,,\n;DES,BHI,STK,SMART/NYSE,,,,,\n\n;DES,BHI,STK,SMART/NYSE,,,,,\n\n\n;DES,BHI,STK,SMART/NYSE,,,,,\nDES,BHI,STK,SMART/NYSE,,,,,\n"
  # total = split( listStringIn, tstStringIn, ";" )
  # for ( n = 0; n <= 2; n++ ) {
  #   for ( j = 2; j <= total; j++ ) {
  #     output = padStringToNumberOfLines( tstStringIn[j], n )
  #     if ( tstStringIn[j] ) { p1 = tstStringIn[j] } else { p1 = "<empty>" }
  #     if ( output ) { p2 = output } else { p2 = "<empty>" }
  #     #print "n=" n "; " tstStringIn[j] " output: " output "  \n"
  #     printf ( "n=%d; %s output: %s----\n", n, p1, p2 )
  #   }
  # }
# function padStringToNumberOfLines( stringIn, n ) {
#   stringOut = stringIn
#   if ( stringIn ) {
#     line = stringIn
#     if ( numberOfLinesIn = gsub( "\n", "@", line ) ) {
#       if ( numberOfLinesIn < n ) {
#         stringOut = appendEmptyLines( stringIn, n - numberOfLinesIn )
#       }
#     } else {
#       stringOut = appendEmptyLines( stringIn, n )  
#     }

#   } else {
#     stringOut = appendEmptyLines( stringIn, n )
#   }

#   return stringOut
# }

# function appendEmptyLines( stringIn, n ) {
#   line = ""
#   for ( i = 1; i <= n; i++ ) {
#     line = line "\n"
#   }
#   stringOut = stringIn line
#   return stringOut
# }


#ftest for function trimStringToNumberOfLines( stringIn, n ):
# //n = 0; <empty>                        output: <empty>
# //n = 0; DES,BHI,STK,SMART/NYSE,,,,,    output: <empty>
# //n = 0; DES,BHI,STK,SMART/NYSE,,,,,@   output: <empty>
# //n = 0; DES,BHI,STK,SMART/NYSE,,,,,@@  output: <empty>
# //n = 0; DES,BHI,STK,SMART/NYSE,,,,,@@@ output: <empty>
# n = 0; DES,BHI,STK,SMART/NYSE,,,,,@DES,BHI,STK,SMART/NYSE,,,,,@ output: <empty>

# //n = 1; <empty>                        output: <empty>
# n = 1; DES,BHI,STK,SMART/NYSE,,,,,    output: DES,BHI,STK,SMART/NYSE,,,,,
# n = 1; DES,BHI,STK,SMART/NYSE,,,,,@   output: DES,BHI,STK,SMART/NYSE,,,,,@
# n = 1; DES,BHI,STK,SMART/NYSE,,,,,@@  output: DES,BHI,STK,SMART/NYSE,,,,,@
# n = 1; DES,BHI,STK,SMART/NYSE,,,,,@@@ output: DES,BHI,STK,SMART/NYSE,,,,,@
# n = 1; DES,BHI,STK,SMART/NYSE,,,,,@DES,BHI,STK,SMART/NYSE,,,,,@ output: DES,BHI,STK,SMART/NYSE,,,,,

# //n = 2; <empty>                        output: <empty>
# n = 2; DES,BHI,STK,SMART/NYSE,,,,,    output: DES,BHI,STK,SMART/NYSE,,,,,
# n = 2; DES,BHI,STK,SMART/NYSE,,,,,@   output: DES,BHI,STK,SMART/NYSE,,,,,@
# n = 2; DES,BHI,STK,SMART/NYSE,,,,,@@  output: DES,BHI,STK,SMART/NYSE,,,,,@@
# n = 2; DES,BHI,STK,SMART/NYSE,,,,,@@@ output: DES,BHI,STK,SMART/NYSE,,,,,@@
# n = 2; DES,BHI,STK,SMART/NYSE,,,,,@DES,BHI,STK,SMART/NYSE,,,,,@ output: DES,BHI,STK,SMART/NYSE,,,,,@DES,BHI,STK,SMART/NYSE,,,,,

#tcode:
# listStringIn = ";DES,BHI,STK,SMART/NYSE,,,,,;DES,BHI,STK,SMART/NYSE,,,,,\n;DES,BHI,STK,SMART/NYSE,,,,,\n\n;DES,BHI,STK,SMART/NYSE,,,,,\n\n\n;DES,BHI,STK,SMART/NYSE,,,,,\nDES,BHI,STK,SMART/NYSE,,,,,\n"
# total = split( listStringIn, tstStringIn, ";" )
# for ( n = 0; n <= 2; n++ ) {
#   for ( j = 2; j <= total; j++ ) {
#     output = trimStringToNumberOfLines( tstStringIn[j], n )
#     if ( tstStringIn[j] ) { p1 = tstStringIn[j] } else { p1 = "<empty>" }
#     if ( output ) { p2 = output } else { p2 = "<empty>" }
#     #print "n=" n "; " tstStringIn[j] " output: " output "  \n"
#     printf ( "n=%d; %s output: %s----\n", n, p1, p2 )
#   }
# }
# function trimStringToNumberOfLines( stringIn, n ) {
#   stringOut = ""
#   if ( stringIn ) {
#     if ( n > 0 ) {
#       dumpStringToFile( stringIn, cacheFileName )
#       #tSTNOL_command = printf( "sed -i \"%dq\" %s", n, cacheFileName ) | 
#       tSTNOL_command = "sed -i -n \"1," n "p\" " cacheFileName
#       system( tSTNOL_command )
#       stringOut = loadTextVarFromFile( cacheFileName )
#     }
#   }
#   return stringOut
# }

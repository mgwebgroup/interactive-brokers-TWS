BEGIN {

	cacheFileName = "cache.tmp"
  fileNameForInputMap = "map.new"
  columnDelimeter = "COLUMN,[0-9]+"
  sectorDelimeter = "HED,[A-Z]+"
  categoryDelimeter = "(HED,MOVER|HED,STRENGTH|HED,ID|HED,WEAKNESS|HED,ACTION_EXPECTED)"
  
  linesInInputMapPerSector = 6
  sectorOrderInInputMap = trimRegExDelimetersInString( "XLF,XLE,XLK,XLI,XLV,XLP,XRT,XLB,XTL,XLU,XLY,XHB", "," )
  sectorTotal = split( sectorOrderInInputMap, sectorOrderInByNum )

  categoryList = trimRegExDelimetersInString( "MOVER,STRENGTH,ID,WEAKNESS,ACTION_EXPECTED,ACTION_EXPECTED", "," )
  categoryScoreList = trimRegExDelimetersInString( "50,10,1,-10,0,0", "," )
  columnsTotal = split( categoryList, categoryByColumnNumber, "," )
  if ( split( categoryScoreList, categoryScoreByColumnNumber ) != columnsTotal ) { 
    warningPrintedAtEnd[1] = "Number of elements in categoryScore needs to match number of elements in categoryList. Check BEGIN section of the program."
    split( "0,0,0,0,0,0,0,0,0,0", categoryScoreByColumnNumber )
  }
	
  textMap = loadTextVarFromFile( fileNameForInputMap )
  textMap = trimRegExDelimetersInString( textMap, columnDelimeter )
  #print textMap; exit
  
  createCategorySectorMap( textMap )

}

END {

  scoreColumnOut = ""
  command = "cat cache.tmp | sed -r \"1s-^[[:alpha:]]+,([[:alpha:]]+,)([[:alpha:]\/\,]+)-\\1-\" | sed -n \"1p\"; sed -i -n \"1d;p\" " cacheFileName
  #print command
  for ( i = 1; i <= columnsTotal; i++ ) {
    categoryName = categoryByColumnNumber[i]
    #print "column=" i " category=" categoryName "\n"
    categoryScore = categoryScoreByColumnNumber[i]
    for ( j = 1; j <= sectorTotal; j++ ) {
      sectorName = sectorOrderInByNum[j]
      #print sectorName "\n"
      categorySectorMap[categoryName,sectorName] = deleteEmptyLines( categorySectorMap[categoryName,sectorName] )
      #print "before scoring: \n" categorySectorMap[categoryName,sectorName]
      dumpStringToFile( categorySectorMap[categoryName,sectorName], cacheFileName )
      for ( k = 1; k <= linesInInputMapPerSector; k++ ) {
        line = ""
        command | getline line
        close( command )
        #print "command=" command " k=" k " line=" line "\n"
        #print "line=" line "\n"
        if ( line ) scoreColumnOut = scoreColumnOut line categoryScore "," sectorName"\n"
      }
      categorySectorMap[categoryName,sectorName] = loadTextVarFromFile( cacheFileName )

    }
  }

  print scoreColumnOut
  printWarnings()

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

function dumpStringToFile( aString, fileName ) {
  print aString > fileName
  close( fileName )
}

function deleteEmptyLines( stringIn ) {
  stringOut = ""
  dumpStringToFile( stringIn, cacheFileName )
  dEL_command = "grep -E \"^DES,[[:alpha:]]+,STK,[[:alpha:]]*/?[[:alpha:]]*,,,,,\" " cacheFileName
  while ( ( dEL_command | getline line ) > 0 ) stringOut = stringOut line "\n"
  close(dEL_command)
  return stringOut
}

function printWarnings() {
  for ( i in warningPrintedAtEnd ) {
    print warningPrintedAtEnd[i] "\n"
  }

}
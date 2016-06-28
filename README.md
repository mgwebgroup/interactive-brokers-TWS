DESCRIPTION
-----------
This set of srcipts was written for Trader Workstation (TWS) which is provided by Interactive Brokers (IB) for the Unix platform. The scripts were designed to enhance the existing functionality of TWS by:
* Match custom scanned stocks from TWS against user Universe.
* Compute "magic levels" for price.
* Update the stock map.
* Score the stock map.

INSTALLATION
------------
Just download the files into directory of your choice. We will use directory "Scans" as an example here.

USAGE
-----
Match custom scanned stocks from TWS against user Universe.
- User Universe must already be created as a .csv file. See file Market Survey_1606.csv as an example of the user Universe.
- Results of the custom scan must already be saved as a .csv file. This can be done through right-clicking on the scan results in TWS and saving them as .csv file. We will use "down_1000.csv" as an example.

Scans> ./display-movers down_1000.csv Market_Survey_1606.csv
A table of stocks will be listed.


Compute "magic levels" for price.
- A data file that contains timestamp and price information must be present and saved as a .dat file. See file "SPY.dat" as an example. This file usually contains a list of extreme price points listed in ascending chronological order (latest dates at bottom of list) as <timestamp>,<price><RET>

Scans> ./levels-compute symbol=SPY
A file SPY.csv will be created, which will contain the "magic levels"


Update the stock map.
- The stock map must be present as "map.old". This file is exported from TWS by right-clicking on watchlist and clicking on "Import/Export"/"Export Page Content..." as a .csv file named "map.old"
- The latest Market Survey file "Market_Survey_YYMM.csv" must be present
- "updatemap.awk" script must be present in same directory as the "updatemap" script.

Scans> ./updatemap Market_Survey_1606.csv
A file name map.new will be created ready for import into TWS. Just clear the existing map in TWS, then right-click and select "Import/Export"/"Import Contracts"


Score the stock map.
As you go over each stock in the TWS map, it will be moved around between the categories or deleted out of the list. The resulting map reflects your opinion about the market. This opinion can be scored and recorded over x number of days in order to spot market trends.
- scoremap.awk script file must be present in same directory.
- Market Survey file must be present. We will use "Market_Survey_1606.csv" as an example.
- New map file must be present. We will use "map.new" as an example.

Scans> ./scoremap <Market\ Survey_YYMM.csv>
A .csv file "Market_Survey_YYMMDD.csv" with scores assigned for each stock will be created and will be ready for import into your general Market_Survey_YYMM.ods file.

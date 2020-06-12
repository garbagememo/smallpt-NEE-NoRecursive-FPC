# smallpt-NEE-NoRecursive-FPC
smallptサイトのNEEと非再帰を適用したFreePascal移植

コードはよく知られる 99行のc++パストレーサーであるsmallpt（Kevin Beason http://www.kevinbeason.com/smallpt/）
からの移植しました。

さらにKevin BeasonさんのNextEventEstimate対応のコードexplicit.cppと非再帰としたforword.cppを適用させました。

その中でexplicit.cppについて下記の部分について修正を行いました。
1.explicit.cppでは視点が光源球の外部にあり、光源球が全て見えるという前提で省略している部分を補完
2.コーネルボックス以外の作例を導入

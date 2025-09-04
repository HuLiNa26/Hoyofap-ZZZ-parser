# HoyofapZZZParser

A software written in Zig to parse equipments from official account through Hoyolab
Create gameplay_settings.zon for [Yidhari-ZS](https://git.xeondev.com/yidhari-zs/Yidhari-ZS)   

## How to use
Save all your json files from Hoyolab to `hoyolab` folder.
Run parser and it will generate gameplay_settings.zon 

## How to get Hoyofap json

<img src="tutorial/1.png" width="300"/><br>
1. Open Battle Records.<br>

<img src="tutorial/2.png" width="1200"/><br>
2.1. Press F12 to enter inspect mode, head to Network tab, choose your character.<br>
2.2. Filter `info?id` and double click one with Type `xhr`.<br>

<img src="tutorial/3.png" width="700"/><br>
3. Ctrl+S to save json file.<br>

<img src="tutorial/4.png" width="700"/><br>
4. Save it to [hoyolab](https://git.xeondev.com/HuLiNap/HoyofapZZZParser/src/branch/master/hoyolab).<br>
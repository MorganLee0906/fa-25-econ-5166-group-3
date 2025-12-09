# research-repo-template
This is the template repository for the ECON 5516 final project.

## How to use this template
1. Click on the "Use this template" button at the top right of the page.
2. Fill in the repository name and description.
3. Click "Create repository from template". 
4. Name the repo in the format 'fa-25-econ-5166-group-x'.
5. Clone the repository to your local machine.
6. Start adding your research files and documentation.

P.S. If you like to keep the repo private, please add me to your repository. My account: yuchangchen@ntu.edu.tw.

## Project Guideline 
See [ECON5166-期末專案的管理與交付規範](https://docs.google.com/document/d/17YY_T9vu77ssXM6swrmNqx23nYT6hnxEF7jRUkGqqV4/edit?usp=sharing).

## Group Information

|  Name | Student ID | Github Account| Role |
| ---| --- | --- | --- |
| 周彥辰 | B12303119 | YCCAlex | PM |
| 吳東彥 | B11202031 | IanWu0408 | DA |
| 袁承亨 | B12303054 |  CHYuan |  DA |
| 李承祐 | B12303039 | MorganLee0906 | DE |
| 姚如謙 | B12303125 | ChaneyYao | DE |
| 林英典 | B12303013 | pzds1124 | DE |
## Link to Meeting Note 
[Link](https://docs.google.com/document/d/1p2yovsH1ZrDv_SO_luVjWbAkwCpAIdtUIq2Vzr30hZA/edit?tab=t.0)
Please create a Google Doc for meeting notes for your project. Please create a tab (named by date YYYYMMDD) for each meeting. [Meeting note template](https://docs.google.com/document/d/1vp1DItfbCN4shOsO1ZbVJf6z8bKySTxFDYsEbWRH10E/).

## Notebook Templates
the folder `notebook-templates` contains the jupyter notebooks and R markdown examples for what you need to do in your research project folder.

## Each Member's Key Contribution
After the poster presentation, please highlight each member's key contribution to the project. Please include the link to specific commits (e.g., a page like [this](https://github.com/yu-chang-chen/FA25-ECON-5166-Group-Project-Template/commit/29e276672f667af5cd7b198871033748fc3ec3ee)) for my reference.

**`姚如謙`**'s contribution
- `用政策範圍內外的空氣品質測站與天氣變數測量紐約市的壅車費政策效果` [初始：d788d6f](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/8f839db5e058dfb7c7c82e09b4353fbe3891c345)；[最終：5b67234](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/5b67234d056616e8742a039916c7f67b2929c412)
- `清理並新增各資料集中的DID term`
    - `地鐵（MTA）資料集` [0e718c9](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/0e718c905f6241cd8d1855505de2e970ad3eec71)
    - `速度與行車紀錄資料集` [d922c90](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/d922c9086367cbd762b60b9dc2dee0c46e513575)
- `清理並整理天氣變數與污染變數` [21e3dc0](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/21e3dc0d5d0b4fb7274d9166d4ebdce1189472b5)
- `用QGIS畫研究範圍地圖（因為不是程式碼，僅上傳圖片）`[fc0d8e0](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/fc0d8e027d0e96f645b785bf3ef2bcbbd494cc07)

**`<周彥辰>`**'s contribution
- `<Group Meeting Note>` [3e6f0e1](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/3e6f0e137904a4d15dcaa074bbfe0e0daf2ed61f)
- `<Research Proposal>` [23d2878](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/23d2878e3deefbba62a88d5c24f69d0759b574f6)
- `<HVFHV Data Cleaning & Processing>` [0112b6e](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/0112b6ef6bad11b679015c80cb63d22491cc2cdd) & [27bd43f](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/27bd43f36fc7c84dc9584b3c0d0bcaff364404c5)
- `<HVFHV Ride Preliminary Statistical Analysis>` [4fd7ed6](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/4fd7ed65e37b8e219b9edad3b8e8cff3543abc71) & [ff7a53f](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/ff7a53fe734899b487fe5ab137996e87637c9d30)
- `<Academic Poster>` 

**`吳東彥`**'s contribution
- `清理 hvfhv 資料; 將其整理成更有效率的存檔格式以便後續分析。` [see commit(.rmd)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/17730b4472e4f783a41ded5694f032dcbb5bec66); [see commit(.html)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/e3b5bb2704e3ac97835427d168e069f6601a389e)
- `對 hvfhv 資料內，依地區別區分的每小時乘車資料做 principal component analysis (PCA); 將數據打包成可以做 Random Forest (RF) 預測模型的格式。` [see commit(.rmd)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/d788d6f8cc9981f919a25146fc40473caad9e32f); [see commit(.html)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/6ad2e4c1ab4ce6162e7e14042a4aef9a5c0ac936)
- `用 Random Forest (RF) 預測每小時進入受政策影響區域的總車流量和平均小費; 將數據打包成可以做統計分析的格式。`[see commit(.rmd)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/53228e4f87c5ea934f0dc20e8e250c2c15e57c87); [see commit(.html)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/348aa6239e22caf0b536c3ce54c0a0f7fb50e57f)
- `用前述步驟預測的總車流量和平均小費作為合成控制組，以圖表和 DiD 估計政策效果。發現總車流量沒有因政策的稅金而改變，代表 hvfhv 乘客的需求彈性很低。但發現乘客透過減少小費的形式，轉嫁一部分的稅金給司機(雍塞費每趟 1.5 美金，每趟乘客平均給司機的小費少了約 0.1 美金)。`[see commit(.rmd)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/3cf8d6433fb04c2a453dc0c4d51203fcb6d8b5f7); [see commit(.html)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/a6c9c5007d5f2d7bec2414aff8800ea31b041e5f)
- `以上步驟的的統計概念，請參考連結附圖。` [see commit(.jepg)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/6e5a0f5edf4771746e863939e33d07698127badb)

**`李承祐`**'s contribution
- `Clean MTA data` [1a007bc](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/1a007bcba6f43d3e641dee6795d4a7e00faf4fce)
- `Merge station information into the dataset (to check whether the station in the CBD)` [3343783](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/3343783322792a7118567ed80a7383e02b657309)
- `Analyze MTA data` [3343783](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/3343783322792a7118567ed80a7383e02b657309) and [ba84974](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/ba84974803c2652f7280e25618e3fedc7dea799a)

**`林英典`**'s contribution
- `Clean NYC speed data into a time plot showing daily average speed in five boroughs` [see commit(.ipynb)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/662c9d856506a95798a3b53ff418d87b93791879)
- `Analyze MTA data, which has been marked if it was in CBD` [see commit(.ipynb)](https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/8b29fd1957b59b190774182a22e83f67aedd79a3)

**`<袁承亨>`**'s contribution
- `Processed and validated DOT traffic speed data, constructing time-series visualizations to evaluate impacts of the congestion pricing within the CBD while controlling for seasonal effects (month), day type (weekday vs. weekend), and intraday variation (hour of day).`  [21452a3] (https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/21452a38dbb394f34e372e8385aa4f0a0507c1a4) and [09ab2cc] (https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/09ab2ccb7b7a8132ba70bfa9be8cb8c5eec22994)

- `Conducted a difference-in-differences (DiD) analysis comparing traffic speeds inside versus outside the Manhattan CBD to estimate the causal effect of the policy.` [4ee24ce] (https://github.com/MorganLee0906/fa-25-econ-5166-group-3/commit/4ee24ce1f4fcc00aefbb83f5489f9d2b19a41ee0)
**_Document Change Log_**

| **Date** | **Changes Made by** | **Reviewed by** | **Description** |
| --- | --- | --- | --- |
| Mar 2021 | Lih Shan Yap | Tonia Atchison | Initial Document |
| April 2024 | Steve Wolfe | DV CoE/Tonia Atchison | Implementation of categorical layout |
| April 2025 | Lih Shan Yap | DV CoE | Updated transport request process  <br>("Power Query" item#6) |

Power BI Development Checklist

Contents

[About the Development Checklist 1](#_Toc659028109)

[Data/Semantic Model Best Practices 1](#_Toc59463662)

[Power Query 4](#_Toc2079342408)

[Performance 5](#_Toc749660221)

[Data Visualization Best Practices 5](#_Toc1706548047)

[DAX Best Practices 7](#_Toc1355827296)

[Deployment (Optional) 9](#_Toc1440456113)

# About the Development Checklist

A summary checklist for developers to verify and ensure reports readiness before deploying to end users or requesting transport to "Certified". Also suggested for after deployment housekeeping activity reminder.

# Data/Semantic Model Best Practices

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | Are all dimensional tables in either Dual or Import for performance? | &nbsp; | &nbsp; |
| 2   | Does the Power BI import model follow a [star schema](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema)? |     |     |
| 3   | Does the Power BI model use only unidirectional relationships? Reference: [Power BI Best Practices (sharepoint.com)](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-Best-Practices.aspx) |     |     |
| 4   | Does the Power BI model use only one-to-many or one-to-one relationships only and DOES NOT have any many-to-many relationship(s)? Many-to-many connections must be [solved with bridge tables per guidance from Microsoft](https://learn.microsoft.com/en-us/power-bi/guidance/relationships-many-to-many). |     |     |
| 5   | Are unnecessary tables, table columns, measures, and calculated columns removed? ([Can be quickly identified with Measure Killer](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-External-Tools.aspx)) |     |     |
| 6   | Have all items from the Best Practice Analyzer from Tabular Editor (ref: [External Tools for Power BI](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-External-Tools.aspx)) been addressed where appropriate? |     |     |
| 7   | Is a [Date table](https://docs.microsoft.com/en-us/power-bi/guidance/model-date-tables) created for use with time series data? You may also choose to utilize the [K-C Date Table in GL COMMON CERTIFIED DATASETS - Public](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/PBI%20Common%20Datasets/Date%20Table.docx?d=w0c0807e851994d4f9301d260746cf8aa&csf=1&web=1&e=EcA1gJ) (ref: [Power BI Tips & Tricks - Dec 2023](https://kimberlyclark.sharepoint.com/:v:/s/H318/EadB52CyIEFGsIH1ld4VxtgBmLjd4Ao4D_k9AeZGS1uCoA?nav=eyJwbGF5YmFja09wdGlvbnMiOnsic3RhcnRUaW1lSW5TZWNvbmRzIjo3NDYuNjk5LCJ0aW1lc3RhbXBlZExpbmtSZWZlcnJlckluZm8iOnsic2NlbmFyaW8iOiJDaGFwdGVyU2hhcmUiLCJhZGRpdGlvbmFsSW5mbyI6eyJpc1NoYXJlZENoYXB0ZXJBdXRvIjpmYWxzZX19fSwicmVmZXJyYWxJbmZvIjp7InJlZmVycmFsQXBwIjoiU3RyZWFtV2ViQXBwIiwicmVmZXJyYWxWaWV3IjoiU2hhcmVDaGFwdGVyTGluayIsInJlZmVycmFsQXBwUGxhdGZvcm0iOiJXZWIiLCJyZWZlcnJhbE1vZGUiOiJ2aWV3In19&e=fOAc9J))  <br>let<br><br>\_base_table = **base_table_here**,<br><br>\_mindate = Date.From(List.Min(\_base_table\[date_field_here**\])),**<br><br>\_maxdate = Date.From(List.Max(\_base_table\[**date_field_here**\])),<br><br>Source = PowerPlatform.Dataflows(null),<br><br>Workspaces = Source{\[Id="Workspaces"\]}\[Data\],<br><br>#"c0ddd27f-49fb-4086-b542-1d69accc331c" = Workspaces{\[workspaceId="c0ddd27f-49fb-4086-b542-1d69accc331c"\]}\[Data\],<br><br>#"19920276-09d7-406c-888f-bda5142788db" = #"c0ddd27f-49fb-4086-b542-1d69accc331c"{\[dataflowId="19920276-09d7-406c-888f-bda5142788db"\]}\[Data\],<br><br>#"Date Table_" = #"19920276-09d7-406c-888f-bda5142788db"{\[entity="Date Table",version=""\]}\[Data\],<br><br>#"Filtered Rows" = Table.SelectRows(#"Date Table_", each \[Date\] >= \_mindate and \[Date\] <= \_maxdate)<br><br>in<br><br>#"Filtered Rows" |     |     |
| 8   | Have you filtered out the data that you do not need from your data model? i.e. make sure you filter the rows in Power Query before loading them into Power BI Desktop, filtering data from years or entities that are not required, etc. Reference: [Data Modelling Best Practices](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/_layouts/15/Doc.aspx?sourcedoc=%7B925E356E-9E23-48DB-811C-727678A0C510%7D&file=Data%20Modelling%20Best%20Practices.docx&action=default&mobileredirect=true) | &nbsp; | &nbsp; |
| 9   | Have you removed all unused bookmarks? | &nbsp; | &nbsp; |
| 10  | For Import model, please review the size limit considerations as stated in [Publish to Power BI Cloud Service](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Publish-to-Power-BI-Cloud-Service.aspx). |     |     |
| 11  | For Import model, please disable the dataset scheduled refresh in Power BI Service Dev/Qual/Ad hoc workspaces after deployed to "Certified". |     |     |
| 12  | Verify if a gateway is needed for your report (i.e., connect to Excel files in K-C network folder, or SQL Server database). If required, please submit your request by filling in the form ([please see Power BI Gateway & the individual data source supporting documents](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-Supported-Data-Sources.aspx#power-bi-gateway)). |     |     |
| 13  | [If there is row-level security (RLS) implemented in your report, please provide the users mapping details to the BI Support team to configure in "Certified" workspace.](https://docs.microsoft.com/en-us/power-bi/enterprise/service-admin-rls) |     |     |
| 14  | Are all tables clearly laid out and easy to understand the relationships within the model view? |     |     |
| 15  | Are all data sources used approved on the [Data Sources used in Power BI](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-Supported-Data-Sources.aspx) page? |     |     |

# Power Query

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | Are parameters used for data connections? This is helpful when switching between databases/locations, and parameters can be changed within the Power BI Service. |     |     |
| 2   | Are data transformations being applied in the data source rather than in PowerQuery, if possible? |     |     |
| 3   | Have all native SQL statements been saved back to the relational database platform as a view for reusability and change management? |     |     |
| 4   | Ensure that there are no errors in the report (i.e., Errors screenshots below). Reference: [Dealing with errors in Power Query](https://docs.microsoft.com/en-us/power-query/dealing-with-errors) |     |     |
| 5   | For Direct Query mode, consider enabling query reduction technique (i.e., Add a single Apply button to the filter pane to apply changes at once). Reference video: [Power BI query reduction when using DirectQuery - YouTube](https://www.youtube.com/watch?v=4kVw0eaz5Ws) |     |     |
| 6   | For [transport to Certified workspace](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-Transport-Process.aspx), please review this document ​​​​[​​​​​​​​​​​​​​How to schedule refreshes to Certified using OKTA Delegated Authentication App](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/HowTo%20Documents/PBI%20-%20How%20to%20schedule%20refreshes%20to%20Certified%20using%20OKTA%20Delegated%20Authentication%20App.docx?d=wa54ff548c0c842f6999e0c2dbc0144cd&csf=1&web=1&e=Ad2yxT) that a Non-User ID is required for the semantic models and dataflows in the Certified workspace to access data or perform scheduled refreshes. |     |     |
| 7   | Have you [avoided the use of the "Any" data type](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwiHz9vf49aGAxV8RzABHUJwB6EQFnoECBEQAw&url=https%3A%2F%2Flearn.microsoft.com%2Fen-us%2Fpower-query%2Fdata-types%23%3A~%3Atext%3DAny%2520is%2520the%2520data%2520type%2Cthe%2520output%2520of%2520your%2520query.&usg=AOvVaw0DTXwqxkfqIcuO8js8_Yob&opi=89978449)? All columns should have well defined data types, and "Any" should be avoided. |     |     |
| 8   | Have all PowerQuery steps that are performing the same actions (renaming, removing, etc.) being performed on single steps rather than multiple ones per [Data Modeling Best Practices](#%28lf%29)? |     |     |
| 9   | Have all sorting steps in PowerQuery been removed unless there is some specific reason for the implementation of PowerQuery functions? |     |     |

# Performance

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | [Was Performance Analyzer executed in Power BI Desktop?](https://docs.microsoft.com/en-us/power-bi/create-reports/desktop-performance-analyzer) |     |     |
| 2   | Do all the DAX queries execute under 1000ms? |     |     |
| 3   | Does the slowest visual on all the report pages load within 3000ms? |     |     |
| 4   | Is Page Load Time calculated for all the pages of the report? |     |     |
| 5   | Is Page Load Time <10s for all pages? |     |     |
| 6   | Was the Best Practice Analyzer executed on the model using Tabular Editor 2.x, and does it show 0 observations? |     |     |
| 7   | Is an image used for static background components instead of multiple Power BI shapes and images? |     |     |
| 8   | Are [visual interactions](https://learn.microsoft.com/en-us/power-bi/create-reports/service-reports-visual-interactions?tabs=powerbi-desktop) turned off wherever not required? | &nbsp; | &nbsp; |
| 9   | Perform testing. Ensure the report is working properly (in both Desktop, Service, and/or Mobile) and output data is accurate. |     |     |
| 10  | Do all queries must return in [less than 180 seconds](https://engage.cloud.microsoft/main/org/kcc.com/threads/eyJfdHlwZSI6IlRocmVhZCIsImlkIjoiMzQ2OTkyMTI3ODU5OTE2OCJ9?trk_copy_link=V2)? |     |     |

# Data Visualization Best Practices

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | Are all slicers, table headers, measures, objects in Proper Case and not CamelCase or With_Underscores? | &nbsp; | &nbsp; |
| 2   | Are currency-related values formatted as currency? | &nbsp; | &nbsp; |
| 3   | Are percentages formatted with a maximum of 1 decimal point? | &nbsp; | &nbsp; |
| 4   | Ideally, all numerical values should be formatted as whole numbers with thousand separators. In instances where decimal points are required for precision, there should be a maximum of 1 decimal point. | &nbsp; | &nbsp; |
| 5   | Is the thousand separator enabled for all numerical values? | &nbsp; | &nbsp; |
| 6   | Is the [KC UX Template](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-UX-Templates.aspx) used? This template not only adheres to K-C brand visualization standards, but also addresses ~10% of the population suffering from colorblind afflictions. | &nbsp; | &nbsp; |
| 7   | Is a standard canvas size of 720px x 1280px being used? This is critical to ensure the background images appear in the same scale per the [UI/UX PowerPoint deck on Power BI UX Templates (sharepoint.com)](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-UX-Templates.aspx). | &nbsp; | &nbsp; |
| 8   | Per [data visualization best practices](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-Best-Practices.aspx), scroll bars should be avoided at all costs. Have all attempts to remove scroll bars from pages/visuals been made so everything appears on a single standardized canvas? | &nbsp; | &nbsp; |
| 9   | Is the [New Card Visual](https://powerbi.microsoft.com/en-us/blog/new-card-visual-public-preview/) being used, rather than the previous Card visual? | &nbsp; | &nbsp; |
| 10  | [Do slicers with more than 5 items (or that have a scroll bar) have the Search functionality enabled?](https://radacad.com/search-bar-in-power-bi-slicer) | &nbsp; | &nbsp; |
| 11  | Visuals and slicers are arranged, aligned, and distributed properly by utilizing the [KC UX Templates](https://kimberlyclark.sharepoint.com/Sites/H318/SitePages/Power-BI-UX-Templates.aspx). | &nbsp; | &nbsp; |
| 12  | Format (such as font types, sizes, and colors) is consistent across all visuals. | &nbsp; | &nbsp; |
| 13  | Calendar dates represented with text (not just numeric value) for global interpretation. [Reference: Power BI Development Visualization Best Practices Guidelines - section 7.1 Development Recommendations, bullet point #6](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/_layouts/15/Doc.aspx?sourcedoc=%7B76E25E84-A282-4D4D-922F-CC20B13146EF%7D&file=Power%20BI%20Development%20Visualization%20Best%20Practices%20Guidelines.docx&action=default&mobileredirect=true) | &nbsp; | &nbsp; |
| 14  | Units and measures must always be made clear. Reference: [Power BI Development Visualization Best Practices Guidelines - section 7.1 Development Recommendations, bullet point #9](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/_layouts/15/Doc.aspx?sourcedoc=%7B76E25E84-A282-4D4D-922F-CC20B13146EF%7D&file=Power%20BI%20Development%20Visualization%20Best%20Practices%20Guidelines.docx&action=default&mobileredirect=true) | &nbsp; | &nbsp; |
| 15  | Do not use "Uncertified" Custom Visuals. [Reference: PBI - Custom Visuals Policy and Issue when Publishing](https://kimberlyclark.sharepoint.com/:w:/r/Sites/H318/_layouts/15/Doc.aspx?sourcedoc=%7B488E9356-335E-4023-9F76-6AA1A06416CE%7D&file=PBI%20-%20Custom%20Visuals%20Policy%20and%20Issue%20when%20Publishing.docx&action=default&mobileredirect=true) | &nbsp; | &nbsp; |
| 16  | Avoid using Pie and Donut charts. Reference: <br><br>[Death to Pie Charts - Storytelling with Data](https://www.storytellingwithdata.com/blog/2011/07/death-to-pie-charts) <br><br>[The Five Stages of Grief Over the Death of Pie Charts](https://uxplanet.org/the-five-stages-of-grief-over-the-death-of-pie-charts-effb54894fee)<br><br>[Pie Charts in Data Visualization- Good, Bad or Ugly? (xviz.com)](https://xviz.com/blogs/pie-charts-good-bad-or-ugly/) | &nbsp; | &nbsp; |

# DAX Best Practices

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | Are [variables](https://docs.microsoft.com/en-us/dax/best-practices/dax-variables) used instead of repeating formula inside the IF-ELSE clause? |     |     |
| 2   | Is [IF.EAGER()](https://docs.microsoft.com/en-us/dax/if-eager-function-dax) used when repeating measures in an IF-ELSE statement? |     |     |
| 3   | Is [DIVIDE()](https://docs.microsoft.com/en-us/dax/best-practices/dax-divide-function-operator) used instead of / with a default value? |     |     |
| 4   | Is [(a-b)/b formula](https://maqsoftware.com/insights/dax-best-practices#:~:text=It%20is%20common%20practice%20to%20use%20a%2Fb%20%E2%80%94%201%20to,will%20filter%20the%20values%20out.) used instead of a/b - 1 or a/b\*100-100? |     |     |
| 5   | Is [SELECTEDVALUE()](https://docs.microsoft.com/en-us/dax/best-practices/dax-selectedvalue) used instead of HASONEVALUE()? |     |     |
| 6   | Are scalar variables used in [SUMMARIZE()](https://docs.microsoft.com/en-us/dax/summarize-function-dax)? |     |     |
| 7   | Is ["= 0" used](https://docs.microsoft.com/en-us/dax/isblank-function-dax) instead of check for "ISBLANK() \| =0"? |     |     |
| 8   | It is preferable to avoid the [FILTER function in DAX](https://docs.microsoft.com/en-us/dax/filter-function-dax). If you must use FILTER, is FILTER(ALL(ColumnName)) used instead of FILTER(VALUES()) or FILTER(T)? |     |     |
| 9   | Is [KEEPFILTERS()](https://www.sqlbi.com/articles/using-keepfilters-in-dax/) used instead of FILTER(T)? |     |     |
| 10  | Is [ISBLANK()](https://forum.enterprisedna.co/t/dax-tip-blank-vs-isblank/19416) used instead of =BLANK() check? |     |     |
| 11  | Is [SEARCH()](https://docs.microsoft.com/en-us/dax/search-function-dax) used with the last parameter? |     |     |
| 12  | Is [SELECTEDVALUE()](https://docs.microsoft.com/en-us/dax/best-practices/dax-selectedvalue) used instead of VALUES()? |     |     |
| 13  | Are the [DISTINCT() and VALUES()](https://powerbitraining.com.au/distinct-vs-values/) used functions consistently? |     |     |
| 14  | Are any [Blank values being shown as 0 or a text string](https://www.robertjengstrom.com/post/replace-blank-with-0-or-text-in-power-bi) instead of "Blank"? | &nbsp; | &nbsp; |
| 15  | You should always use explicit measures for performance and change management<br><br>[](https://www.ehansalytics.com/blog/2023/9/29/always-use-explict-measures-wait-what-is-an-explicit-measure)[Always Use Explicit Measures - Wait, What Is An Explicit Measure? - ehansalytics](https://www.ehansalytics.com/blog/2023/9/29/always-use-explict-measures-wait-what-is-an-explicit-measure) |     |     |
| 16  | Is a [SWITCH() function](https://www.datacamp.com/tutorial/switch-in-dax-for-power-bi) used rather than nested IF() statements? |     |     |
| 17  | Has all commented code been removed? You should not leave DAX code commented out in DAX. |     |     |
| 18  | Have comments been left in the DAX code to explain what the intent behind the code is? This is very helpful to remind you in the future, or for other developers who are taking over your report in the future. |     |     |
| 19  | Are all measures formatted correctly? (Typically need thousand separator and formatted as a number rather than "General"). |     |     |

# Deployment (Optional)

| #   | Item | ✔️/ ❌/ NA | &lt;<Date&gt;> |
| --- | --- | --- | --- |
| 1   | Is the report being deployed from one environment to another using PBI Deployment Pipelines (D > Q > Adhoc)? |     |     |
| 2   | Are correct report parameters configured in the [PBI deployment pipeline](https://learn.microsoft.com/en-us/fabric/cicd/deployment-pipelines/intro-to-deployment-pipelines) as per the target Workspace? |     |     |
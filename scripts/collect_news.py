"""
Script 3: News Article Scraper (Google News RSS)
------------------------------------------------
Fetches recent news articles about Paytm & BharatPe.

Output:
    news_articles.csv

Install:
    pip install requests pandas
"""


import time
import requests
import pandas as pd

from datetime import datetime, timezone
from urllib.parse import quote
from xml.etree import ElementTree as ET



# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────


NEWS_QUERIES = [

    "Paytm decline India",

    "Paytm RBI ban 2024",

    "Paytm users leaving",

    "Paytm Payments Bank shutdown",

    "BharatPe fraud controversy",

    "BharatPe Ashneer Grover",

    "BharatPe users problem",

    "UPI market share India 2024",

    "PhonePe GPay dominance India",

    "fintech decline India 2024"

]


MAX_ARTICLES_PER_QUERY = 20


CUTOFF_DATE = datetime(

    2023,

    1,

    1,

    tzinfo=timezone.utc

)


OUTPUT_FILE = "news_articles.csv"



HEADERS = {

    "User-Agent":

    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

}





# ─────────────────────────────────────────────
# PARSE DATE
# ─────────────────────────────────────────────


def parse_rss_date(date_str):


    formats = [

        "%a, %d %b %Y %H:%M:%S %z",

        "%a, %d %b %Y %H:%M:%S GMT"

    ]


    for fmt in formats:


        try:


            dt = datetime.strptime(

                date_str.strip(),

                fmt

            )


            if dt.tzinfo is None:

                dt = dt.replace(

                    tzinfo=timezone.utc

                )


            return dt



        except ValueError:

            continue



    return None





# ─────────────────────────────────────────────
# FETCH GOOGLE NEWS RSS
# ─────────────────────────────────────────────


def fetch_google_news(query):


    encoded_query = quote(query)


    url = (

        "https://news.google.com/rss/search?"

        f"q={encoded_query}"

        "&hl=en-IN"

        "&gl=IN"

        "&ceid=IN:en"

    )



    try:


        response = requests.get(

            url,

            headers=HEADERS,

            timeout=15

        )


        response.raise_for_status()



    except Exception as e:


        print(

            "Request failed:",

            query,

            e

        )


        return []





    articles = []



    try:


        root = ET.fromstring(

            response.content

        )


        channel = root.find(

            "channel"

        )


        if channel is None:

            return []




        items = channel.findall(

            "item"

        )



        for item in items[:MAX_ARTICLES_PER_QUERY]:


            title = item.findtext(

                "title",

                ""

            )


            link = item.findtext(

                "link",

                ""

            )


            source = item.findtext(

                "source",

                ""

            )



            pub_date = parse_rss_date(

                item.findtext(

                    "pubDate",

                    ""

                )

            )



            if pub_date and pub_date < CUTOFF_DATE:

                continue




            articles.append({

                "query": query,


                "date":

                pub_date.strftime(

                    "%Y-%m-%d"

                )
                if pub_date else "",


                "title": title,


                "source": source,


                "url": link

            })



    except Exception as e:


        print(

            "XML parsing failed:",

            e

        )



    return articles





# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────


def main():


    print("=" * 55)

    print(
        "Google News RSS Scraper"
    )

    print(
        "Total queries:",
        len(NEWS_QUERIES)
    )

    print(
        "Articles per query:",
        MAX_ARTICLES_PER_QUERY
    )

    print(
        "Since:",
        CUTOFF_DATE.date()
    )

    print("=" * 55)



    all_articles = []

    seen_urls = set()



    for query in NEWS_QUERIES:


        print(

            "\nFetching:",

            query

        )



        articles = fetch_google_news(

            query

        )



        new_articles = [

            a

            for a in articles

            if a["url"] not in seen_urls

        ]



        for article in new_articles:

            seen_urls.add(

                article["url"]

            )



        all_articles.extend(

            new_articles

        )



        print(

            "New articles found:",

            len(new_articles)

        )



        time.sleep(1.5)





    if not all_articles:


        print(

            "No articles collected"

        )

        return





    df = pd.DataFrame(

        all_articles

    )



    df = df.sort_values(

        "date",

        ascending=False

    )



    df.to_csv(

        OUTPUT_FILE,

        index=False,

        encoding="utf-8-sig"

    )



    print("\nCompleted")

    print(

        "Saved file:",

        OUTPUT_FILE

    )

    print(

        "Total articles:",

        len(df)

    )



    print("\nTop sources:")


    print(

        df["source"]

        .value_counts()

        .head(10)

    )



    print("=" * 55)





if __name__ == "__main__":

    main()
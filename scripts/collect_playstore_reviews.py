"""
Google Play Store Review Scraper
--------------------------------
Scrapes reviews for Paytm, BharatPe, PhonePe, and GPay.

Output:
    playstore_reviews.csv

Install:
    pip install google-play-scraper pandas tqdm
"""


import time
import pandas as pd

from datetime import datetime, timezone
from tqdm import tqdm

from google_play_scraper import reviews, Sort



# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

APPS = {

    "Paytm": "net.one97.paytm",

    "BharatPe": "com.bharatpe.app",

    "PhonePe": "com.phonepe.app",

    "GPay": "com.google.android.apps.nbu.paisa.user"

}


REVIEWS_PER_APP = 1000

LANGUAGE = "en"

COUNTRY = "in"


CUTOFF_DATE = datetime(
    2023,
    1,
    1,
    tzinfo=timezone.utc
)


OUTPUT_FILE = "playstore_reviews.csv"



# ─────────────────────────────────────────────
# SCRAPER
# ─────────────────────────────────────────────


def scrape_app(app_name, package_id):

    print("\nProcessing:", app_name)


    collected = []

    token = None


    while len(collected) < REVIEWS_PER_APP:


        try:

            batch, token = reviews(

                package_id,

                lang=LANGUAGE,

                country=COUNTRY,

                sort=Sort.NEWEST,

                count=200,

                continuation_token=token

            )


        except Exception as e:

            print(
                "Error while fetching:",
                e
            )

            break



        if not batch:

            break



        for r in batch:


            review_date = r["at"]


            if review_date.tzinfo is None:

                review_date = review_date.replace(
                    tzinfo=timezone.utc
                )



            if review_date < CUTOFF_DATE:

                print(
                    "Reached cutoff date"
                )

                return collected



            collected.append({

                "app": app_name,

                "review_id": r["reviewId"],

                "date": review_date.strftime(
                    "%Y-%m-%d"
                ),

                "rating": r["score"],

                "review_text": r["content"],

                "thumbs_up": r["thumbsUpCount"],

                "app_version": r.get(
                    "appVersion",
                    ""
                )

            })



        print(
            "Collected:",
            len(collected)
        )



        if token is None:

            break



        time.sleep(1)



    return collected[:REVIEWS_PER_APP]





# ─────────────────────────────────────────────
# MAIN EXECUTION
# ─────────────────────────────────────────────


all_reviews = []



print("="*50)

print("Google Play Store Review Scraper")

print("Apps:", ", ".join(APPS.keys()))

print("="*50)



for name, package in APPS.items():


    data = scrape_app(
        name,
        package
    )


    all_reviews.extend(data)


    print(
        name,
        "completed:",
        len(data),
        "reviews"
    )





# ─────────────────────────────────────────────
# DATA CLEANING
# ─────────────────────────────────────────────


df = pd.DataFrame(all_reviews)



if len(df) == 0:

    print(
        "No reviews collected"
    )

else:


    df["review_text"] = (

        df["review_text"]

        .fillna("")

        .str.strip()

    )



    df = df[
        df["review_text"] != ""
    ]



    df = df.drop_duplicates(
        subset="review_id"
    )



    df = df.sort_values(

        ["app", "date"],

        ascending=[True, False]

    )



    df.to_csv(

        OUTPUT_FILE,

        index=False,

        encoding="utf-8-sig"

    )



    print("\nCompleted")

    print(
        "Saved:",
        OUTPUT_FILE
    )


    print("\nApp summary:")


    print(

        df.groupby("app")["rating"]

        .agg(

            count="count",

            average_rating="mean"

        )

        .round(2)

    )
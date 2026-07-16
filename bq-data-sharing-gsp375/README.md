# Share Data using Google Data Cloud: Challenge Lab (GSP375) Solver

Automated scripts for GSP375. This lab involves two roles: **Data Sharing Partner** and **Customer**. Since you are given two separate credentials, you will run the scripts in their respective Cloud Shell environments.

---

## Part 1. Data Sharing Partner Tasks (Task 1)

1. Open a new Google Cloud Console session using the **Data Sharing Partner** credentials.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-data-sharing-gsp375
chmod +x solve_partner.sh
./solve_partner.sh
```

3. Press **Enter** to accept the default values (it will automatically configure view `authorized_view_vv1z` and grant access to `student-03-db01902f575a@qwiklabs.net`).
4. Click **Check my progress** for Task 1 in the Qwiklabs panel.

---

## Part 2. Customer Tasks (Tasks 2 & 3)

1. Open another Google Cloud Console session using the **Customer** credentials (or switch project/account in Cloud Shell).
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-data-sharing-gsp375
chmod +x solve_customer.sh
./solve_customer.sh
```

3. Press **Enter** to accept all default values.
4. Click **Check my progress** for Tasks 2 & 3 in the Qwiklabs panel.

---

## Part 3. Looker Studio Visualization (Task 4)

1. While logged in as the **Data Sharing Partner**, open [Looker Studio](https://lookerstudio.google.com/).
2. Create a **Blank Report**.
3. Under data sources, select **BigQuery** -> **My Projects** -> **qwiklabs-gcp-00-f02f67f8365d (Customer Project ID)** -> **customer_dataset** -> **customer_authorized_view_sp0g**.
4. Add it to the report.
5. In the top-left, rename the report to: `Data Sharing Partner Vizualization`
6. Insert a **Vertical Bar Chart** (Column Chart).
7. Configure the chart:
   * **Dimension**: `county`
   * **Breakdown Dimension**: `Count`
   * **Metric**: `Count`
8. Click **Check my progress** for Task 4 in Qwiklabs.

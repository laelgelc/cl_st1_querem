import argparse
import pandas as pd
from bs4 import BeautifulSoup

def transform_subtitle(subtitle):
    parts = subtitle.split()
    return f"f{parts[1]}{parts[2]}"

def parse_html(loadtable_filepath):
    with open(loadtable_filepath, 'r', encoding='utf-8') as file:
        soup = BeautifulSoup(file, 'lxml')

    body = soup.body
    tables_data = {}

    for div_tag in body.find_all('div', class_='branch'):
        table = div_tag.find('table', class_='systitleandfootercontainer')
        if table:
            title_tag = table.find('td', class_='c systemtitle')
            subtitle_tag = table.find('td', class_='c systemtitle2')
            if subtitle_tag:
                title = title_tag.get_text(strip=True) if title_tag else 'No Title'
                subtitle = subtitle_tag.get_text(strip=True) if subtitle_tag else 'No Subtitle'
            else:
                title = 'No Title'
                subtitle = title_tag.get_text(strip=True) if title_tag else 'No Subtitle'

            data_table = div_tag.find_next('table', class_='table')
            if data_table:
                rows = data_table.find_all('tr')
                data = []
                for row in rows:
                    cols = row.find_all(['th', 'td'])
                    cols = [col.get_text(strip=True) for col in cols]
                    data.append(cols)

                df = pd.DataFrame(data[1:], columns=data[0])
                tables_data[subtitle] = df

    return tables_data

def write_to_file(tables_data, output_filepath):
    with open(output_filepath, 'w', encoding='utf-8') as file:
        for subtitle, df in tables_data.items():
            transformed_subtitle = transform_subtitle(subtitle)
            for index, row in df.iterrows():
                value = row.iloc[2]  # Assuming the third column contains the required values
                if len(row) > 4 and ')' in row.iloc[4]:  # Checking if the DataFrame has 5 columns (as a safeguard) and if the fifth column contains ')'
                    value += ' (secondary)'
                file.write(f"{transformed_subtitle} {value}\n")

def main():
    parser = argparse.ArgumentParser(description='Extract factors from HTML file')
    parser.add_argument('--project', type=str, required=True, help='Project name')
    args = parser.parse_args()

    project = args.project
    loadtable_filepath = f"./sas/output_{project}/loadtable.html"
    output_filepath = './examples/factors'

    tables_data = parse_html(loadtable_filepath)
    write_to_file(tables_data, output_filepath)
    print(f"'{output_filepath}' file successfully created!")

if __name__ == "__main__":
    main()
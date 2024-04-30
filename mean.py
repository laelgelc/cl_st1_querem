import numpy as np
import pandas as pd

# create dataframe from file
dataframe = pd.read_csv("data.csv")

list = dataframe.mean()

with pd.option_context('display.max_rows', None,
					'display.max_columns', None,
					'display.precision', 8,
					'display.width', 20,
					):

   print(list)

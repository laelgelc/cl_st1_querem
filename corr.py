import numpy as np
import pandas as pd

#https://www.geeksforgeeks.org/create-a-correlation-matrix-using-python/

# create dataframe from file
dataframe = pd.read_csv("data.csv")

# show dataframe
#print(dataframe)

# use corr() method on dataframe to
# make correlation matrix
matrix = dataframe.corr()

# print correlation matrix
#print("Correlation Matrix is : ")
#print(matrix)

with pd.option_context('display.max_rows', None,
					'display.max_columns', None,
					'display.precision', 8,
					'display.width', 20000,
					):
	print(matrix)


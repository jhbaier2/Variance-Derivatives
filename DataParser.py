import pandas as pd

"""
File contains two functions to parse both csv files
"""
def GetOptionsData(directory):
    """
    function inputs directory for options data csv
    returns pandas data frame with options data
    input directory as string
    """

    op_data = pd.read_csv(directory)
    return op_data

def GetRateData(directory):
    """
    function inputs directory for rate data csv
    returns pandas data frame with rate data
    input directory as string
    """

    rt_data = pd.read_csv(directory)
    return rt_data
def getTableStructure(response_json_file,templateName):
    """Output: out"""

    import json

    column_definitions=''

    try:
        with open(response_json_file, encoding='utf-8') as fh:
            data = json.load(fh)

        for template in data["Templates"]: #iterate over list elements - template is for example {'Document-Template'  : ..} {'Process-Template': ..}
            if list(template.keys())[0] == templateName: # casting each dictionary {'Document-Template'  : ..} to list ane getting [0] element to get string from key ex. Document-Template
                # when found matching template for a table iterating over columns
                idx=1
                for dict_col_name_ext in list(template.values())[0]: # [0] is required as it is dictionary nested in list dict_values([[{'id': : {'dataType': 'integer', 'length': 0}},... ]]}
                    column_name=list(dict_col_name_ext.keys())[0]
                    column_type=list(dict_col_name_ext.values())[0]['dataType']
                    column_length=list(dict_col_name_ext.values())[0]['length']

                    #special remaping columns
                    if column_type in ('uniqueidentifier', 'binary'):
                        column_type='string'
                    
                    #standard remaping and adding column size
                    if column_type=='string':
                        column_type='varchar'
                    elif column_type=='boolean':
                        column_type='varchar'
                        column_length='5'
                    

                    #remaping number datatype as it can reffer to int or float
                    if column_type=='number':
                        column_type='DECIMAL'
                        column_length='18,2'

                    #type remaping for datetime columns
                    if column_type=='date-time':
                        column_type='TIMESTAMP(6) WITH TIME ZONE'
                        
                    #cutting columns that are too long for oracle
                    try:
                        if column_length > 64000:
                            column_length=64000
                    except Exception as e_convert:
                        print (e_convert)

                    #remapping length (for integer or other columns that do not need to have lenght spec in teradata)
                    if column_length==0 or column_type=='TIMESTAMP(6) WITH TIME ZONE':
                        column_definiton=column_type
                    else:
                        column_definiton=column_type+ '(' + str(column_length) + ')'
                        
  

                    #columns to ignore (binary attachments) - wont be possible to upload to oracle thru sas json map
                    ignore=0
                    if column_name in ('DataStream'):
                        ignore=1

                    if ignore == 0:
                        if idx==1:
                            column_definitions='"'+str(column_name)+'" '+str(column_definiton)+' ,'
                            idx=0
                        else:
                            column_definitions=column_definitions+' "'+str(column_name)+'" '+str(column_definiton)+' ,'


        last_comma_index = column_definitions.rfind(',')
        column_definitions = column_definitions[:last_comma_index] 

    except Exception as e:
        column_definitions=e
    return column_definitions

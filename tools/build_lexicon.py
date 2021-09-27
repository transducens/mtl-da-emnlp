import sys

dic={}
for line in sys.stdin:
    fields=line.strip().split()
    if fields[0] != "NULL" and fields[1] != "NULL":
        if fields[0] not in dic:
            dic[fields[0]]={}
            dic[fields[0]]=(fields[1], float(fields[2]))
        elif dic[fields[0]][1] < float(fields[2]):
            dic[fields[0]]=(fields[1], float(fields[2]))

for s,pair in dic.items():
    print(pair[0]+"\t"+s+"\t"+str(pair[1]))


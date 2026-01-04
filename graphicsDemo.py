import time
from graphics import *

def main():

    n = 50
    
    height = 20 #inaltimea unui dreptunghi
    windowSizeY = height*n

    win = GraphWin("// PROCESSES //", 800, windowSizeY)
    win.setBackground(color_rgb(0,0,0))

    def makeRectangle(x1,y1,x2,y2,*clr):
        rect = Rectangle(Point(x1,y1), Point(x2,y2))
        rect.setFill(color_rgb(0,0,0))
        if clr:
            rect.setFill(clr)
        rect.setOutline(color_rgb(0,255,0))
        if clr:
            rect.setOutline(clr)
        rect.setWidth(2)
        return rect

    def makeTriangle(x1,y1,x2,y2,x3,y3,*clr):
        tri = Polygon(Point(x1,y1),Point(x2,y2),Point(x3,y3))
        tri.setFill(color_rgb(0,0,0))
        if clr:
            tri.setFill(clr)
        tri.setOutline(color_rgb(0,255,0))
        if clr:
            tri.setOutline(clr)
        tri.setWidth(2)
        return tri
    
    pbcpu = makeRectangle(20,20,21,20+height,color_rgb(0,255,0)) #progress bar pt cpu
    pbcpu.draw(win)

    pbram = makeRectangle(420,20,421,20+height,color_rgb(0,255,0)) #progress bar pt ram (used)
    pbram.draw(win)

    pbram1 = makeRectangle(420,20,421,20+height,color_rgb(255,255,0)) #progress bar pt ram (shared)
    pbram1.draw(win)

    headerList = [] # 0 - cpu used text ; 1 - ram used text
    chartLIST = []
    chartRECT = []
    textList = []  
    sizeX = [100,100,125,75,200,200]
    header = ["PID", "USER", "RAM", "%CPU", "TIME", "COMMAND"]
    
    chartENTRIES=30

    def makeText(x1,y1,str,textSize):
        text = Text(Point(x1,y1),str)
        text.setTextColor(color_rgb(0,255,0))
        text.setSize(textSize)
        return text

    def updateText(file_in,usage_file_in,win : GraphWin):
        with open(file_in,"r") as f:
            for l,linie in enumerate(f):
                if l > 0 and l < n-1:
                    for i,info in enumerate( linie.strip().split() ):
                        ramUsed=0
                        cpuUsed=0
                        if i==2:
                            ramUsed = int(info) >> 10
                            info = str(int(info) >> 10) + " MB"
                        if i==3:
                            cpuUsed = float(info)
                        textList[(l)*6+i].setText(info)
        
        valuesLIST = []
        with open(usage_file_in,"r") as uf:
            for l,linie in enumerate(uf):
                values = linie.strip().split()
                if l > 0:
                    valuesLIST.append(values)
        if len(valuesLIST)>0:
            valuesEnd = valuesLIST[0]
            headerList[0].setText(valuesEnd[0] + "% CPU USED")
            headerList[1].setText(valuesEnd[1] + "% RAM USED | " + valuesEnd[2] + "% RAM SHARED | " + str(int(valuesEnd[3])) + "MB TOTAL" )

            return [valuesEnd[0],valuesEnd[1],valuesEnd[2]]
        return []
    
    def addChartElement(sizeOfCol,chartLen):
        xstart = chartLen*sizeOfCol
        p_cpu = int(float(ret[0]))
        p_ram = int(float(ret[1]))
        p_ram1 = int(float(ret[2]))
        cpu_rect=makeRectangle(20+xstart, 100-p_cpu+45, 20+xstart+sizeOfCol, 145, color_rgb(0,255,0))
        ram_rect=makeRectangle(420+xstart, 100-p_ram+45, 420+xstart+sizeOfCol, 145, color_rgb(0,255,0))
        ram1_rect=makeRectangle(420+xstart, 100-p_ram1+45, 420+xstart+sizeOfCol, 145, color_rgb(255,255,0))
        cpu_rect.draw(win)
        ram_rect.draw(win)
        ram1_rect.draw(win)

        chartRECT.append([cpu_rect,ram_rect,ram1_rect])

        def intify(x):
            return int(float(x))
                
        if chartLen > 0:
            lastElem=chartLIST[len(chartLIST)-1]
            y0=100-p_cpu+45
            y1=100-p_ram+45
            y2=100-p_ram1+45
            dy0=100-intify(lastElem[0])+45
            dy1=100-intify(lastElem[1])+45
            dy2=100-intify(lastElem[2])+45
            if dy0 > y0:
                cpu_tri=makeTriangle(20+(xstart-sizeOfCol),dy0,20+xstart, y0, 20+xstart, dy0,color_rgb(0,255,0))
                cpu_tri.draw(win)
                chartRECT[len(chartRECT)-2].append(cpu_tri)
            else:
                cpu_tri=makeTriangle(20+xstart,dy0,20+(xstart+sizeOfCol), y0, 20+xstart, y0,color_rgb(0,255,0))
                cpu_tri.draw(win)
                chartRECT[len(chartRECT)-1].append(cpu_tri)
            if dy1 > y1:
                ram_tri=makeTriangle(420+(xstart-sizeOfCol),dy1,420+xstart, y1, 420+xstart, dy1,color_rgb(0,255,0))
                ram_tri.draw(win)
                chartRECT[len(chartRECT)-2].append(ram_tri)
            else:
                ram_tri=makeTriangle(420+xstart,dy1,420+(xstart+sizeOfCol), y1, 420+xstart, y1,color_rgb(0,255,0))
                ram_tri.draw(win)
                chartRECT[len(chartRECT)-1].append(ram_tri)
            if dy2 > y2:
                ram1_tri=makeTriangle(420+(xstart-sizeOfCol),dy2,420+xstart, y2, 420+xstart, dy2,color_rgb(255,255,0))
                ram1_tri.draw(win)
                chartRECT[len(chartRECT)-2].append(ram1_tri)
            else:
                ram1_tri=makeTriangle(420+xstart,y2,420+(xstart+sizeOfCol), y2, 420+xstart, y2,color_rgb(255,255,0))
                ram1_tri.draw(win)
                chartRECT[len(chartRECT)-1].append(ram1_tri)
        return chartRECT

    makeRectangle(20,20,320,20+height).draw(win) #bounding box pt cpu
    tcpu = makeText(20+300/2, height/2, "?%", 12)
    tcpu.draw(win)
    headerList.append(tcpu)

    makeRectangle(420,20,720,20+height).draw(win) #bounding box pt ram
    tram = makeText(420+300/2, height/2, "?%", 12)
    tram.draw(win)
    headerList.append(tram)
    
    makeRectangle(20,45,320,145).draw(win) #bounding box pt grafic cpu
    makeRectangle(420,45,720,145).draw(win) #bounding box pt grafic ram

    for y1 in range(9,n+9):
        x1 = 0
        for width in sizeX:
            makeRectangle(x1, y1*height, x1+width, (y1+1)*height).draw(win)
            
            text = makeText(x1+width/2, y1*height+height/2,"???",12)
            text.draw(win)
            textList.append( text )
            x1 += width

    for i in range(0,6):
        textList[i].setText(header[i])
    
    while 1:
        ret = updateText("report.txt","deviceUsage.txt",win)
        if len(ret) > 0:
            x0=ret[0]
            x1=ret[1]
            x2=ret[2]
            newpbcpu = makeRectangle(20,20,20+int(3*float(x0)),40,color_rgb(0,255,0))
            newpbcpu.draw(win)

            newpbram = makeRectangle(420,20,420+int(3*float(x1)),40,color_rgb(0,255,0))
            newpbram.draw(win)

            newpbram1 = makeRectangle(420,20,420+int(3*float(x2)),40,color_rgb(255,255,0))
            newpbram1.draw(win)
            
            pbcpu.undraw()
            pbram.undraw()
            pbram1.undraw()
            
            pbcpu=newpbcpu
            pbram=newpbram
            pbram1=newpbram1

            sizeOfCol=int(300/chartENTRIES)
            chartLen=len(chartLIST)
            if chartLen < chartENTRIES:
                #adaugam dreptunghi la final
                chartRECT=addChartElement(sizeOfCol,chartLen)
            else:
                #elim primul, mutam dreptunghiurile la stanga si adaugam dreptunghi la final
                firstEntry=chartRECT[0]
                chartRECT.pop(0)
                for entry in chartRECT:
                    for geom in entry:
                        geom.move(-sizeOfCol,0)
                chartRECT=addChartElement(sizeOfCol,chartLen-1)
                for geom in firstEntry:
                    geom.undraw()
            
            chartLen = len(chartLIST)-1
            if chartLen < chartENTRIES-1:
                chartLIST.append(ret) #30 valori
            else:
                chartLIST.pop(0)
                chartLIST.append(ret)


        time.sleep(1.25)
    

    win.getMouse()
    win.close()

main()

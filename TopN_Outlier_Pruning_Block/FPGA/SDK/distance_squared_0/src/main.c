/*
 * Copyright (c) 2009 Xilinx, Inc.  All rights reserved.
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

/*
 * helloworld.c: simple test application
 */

#include <stdio.h>
#include "platform.h"
#include "xparameters.h"
#include "xscugic.h"
#include "xaxidma.h"
#include "xdistance_squared.h"
#include "xil_printf.h"

extern XDistance_squared example;
volatile static int RunExample = 0;
volatile static int ResultExample = 0;

XDistance_squared example;

XDistance_squared_Config example_config = {
		0,
		XPAR_DISTANCE_SQUARED_TOP_0_S_AXI_CONTROL_BUS_BASEADDR
};

//Interrupt Controller Instance
XScuGic ScuGic;

// AXI DMA Instance
XAxiDma AxiDmaA;
XAxiDma AxiDmaB;

const int SIZE = 256;


int ExampleSetup(){
	return XDistance_squared_Initialize(&example,&example_config);
}

void ExampleStart(void *InstancePtr){
	XDistance_squared *pExample = (XDistance_squared *)InstancePtr;
	XDistance_squared_InterruptEnable(pExample,1);
	XDistance_squared_InterruptGlobalEnable(pExample);
	XDistance_squared_Start(pExample);
}

void ExampleIsr(void *InstancePtr){
	XDistance_squared *pExample = (XDistance_squared *)InstancePtr;


	//Disable the global interrupt
	XDistance_squared_InterruptGlobalDisable(pExample);
    //Disable the local interrupt
	XDistance_squared_InterruptDisable(pExample,0xffffffff);


	// clear the local interrupt
	XDistance_squared_InterruptClear(pExample,1);

	ResultExample = 1;
	// restart the core if it should run again
	if(RunExample){
		ExampleStart(pExample);
	}
}

int SetupInterrupt()
{
	//This functions sets up the interrupt on the ARM
	int result;
	XScuGic_Config *pCfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
	if (pCfg == NULL){
		xil_printf("Interrupt Configuration Lookup Failed\n\r");
		return XST_FAILURE;
	}
	result = XScuGic_CfgInitialize(&ScuGic,pCfg,pCfg->CpuBaseAddress);
	if(result != XST_SUCCESS){
		return result;
	}
	// self test
	result = XScuGic_SelfTest(&ScuGic);
	if(result != XST_SUCCESS){
		return result;
	}
	// Initialize the exception handler
	Xil_ExceptionInit();
	// Register the exception handler
	//xil_printf("Register the exception handler\n\r");
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,&ScuGic);
	//Enable the exception handler
	Xil_ExceptionEnable();
	// Connect the Adder ISR to the exception table
	//xil_printf("Connect the Adder ISR to the Exception handler table\n\r");
	result = XScuGic_Connect(&ScuGic,XPAR_FABRIC_DISTANCE_SQUARED_TOP_0_INTERRUPT_INTR,(Xil_InterruptHandler)ExampleIsr,&example);
	if(result != XST_SUCCESS){
		return result;
	}
	//xil_printf("Enable the Adder ISR\n\r");
	XScuGic_Enable(&ScuGic,XPAR_FABRIC_DISTANCE_SQUARED_TOP_0_INTERRUPT_INTR);
	return XST_SUCCESS;
}

int init_dma(){
	XAxiDma_Config *CfgPtrA;
	XAxiDma_Config *CfgPtrB;
	int status;

	CfgPtrA = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
	if(!CfgPtrA){
		xil_printf("Error looking for AXI DMA config\n\r");
		return XST_FAILURE;
	}
	CfgPtrB = XAxiDma_LookupConfig(XPAR_AXI_DMA_1_DEVICE_ID);
	if(!CfgPtrB){
		xil_printf("Error looking for AXI DMA config\n\r");
		return XST_FAILURE;
	}
	status = XAxiDma_CfgInitialize(&AxiDmaA,CfgPtrA);
	if(status != XST_SUCCESS){
		xil_printf("Error initializing DMA\n\r");
		return XST_FAILURE;
	}
	status = XAxiDma_CfgInitialize(&AxiDmaB,CfgPtrB);
		if(status != XST_SUCCESS){
			xil_printf("Error initializing DMA\n\r");
			return XST_FAILURE;
		}
	//check for scatter gather mode
	if(XAxiDma_HasSg(&AxiDmaA)){
		xil_printf("Error DMA configured in SG mode\n\r");
		return XST_FAILURE;
	}
	if(XAxiDma_HasSg(&AxiDmaB)){
		xil_printf("Error DMA configured in SG mode\n\r");
		return XST_FAILURE;
	}
	//disable the interrupts
	XAxiDma_IntrDisable(&AxiDmaA, XAXIDMA_IRQ_ALL_MASK,XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrDisable(&AxiDmaA, XAXIDMA_IRQ_ALL_MASK,XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrDisable(&AxiDmaB, XAXIDMA_IRQ_ALL_MASK,XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrDisable(&AxiDmaB, XAXIDMA_IRQ_ALL_MASK,XAXIDMA_DMA_TO_DEVICE);

	return XST_SUCCESS;
}

double distance_squared_sw(const double vector1[], const double vector2[]) {
    unsigned int dim;
    double result = 0;
    for (dim = 0; dim < (unsigned) SIZE; dim++) {
        const double vector1_data            = vector1[dim];
        const double vector2_data            = vector2[dim];
        const double diff                    = vector1_data - vector2_data;
        const double diff_squared            = diff * diff;
        result                              += diff_squared;
    }
    return result;
}

int main()
{
    init_platform();

    xil_printf("Example of AutoESL and DMA transfers\n\r");
    double A[SIZE];
    double B[SIZE];
    double result_hw;
    double result_sw;
    int i;
    int status;

    for (i=0; i < SIZE; i++){
    	A[i] = (double)i;
    	B[i] = (double)(2*i);
    }

    //Setup the matrix mult
    status = ExampleSetup();
    if(status != XST_SUCCESS){
    	xil_printf("Example setup failed\n\r");
    }
    //Setup the interrupt
    status = SetupInterrupt();
    if(status != XST_SUCCESS){
        xil_printf("Interrupt setup failed\n\r");
    }

    ExampleStart(&example);

    status = init_dma();

    //flush the cache
    unsigned int dma_size = SIZE * sizeof(unsigned int);
    Xil_DCacheFlushRange((unsigned)A,dma_size);
    Xil_DCacheFlushRange((unsigned)B,dma_size);


    //transfer to hw
    status = XAxiDma_SimpleTransfer(&AxiDmaA,(unsigned)A,dma_size,XAXIDMA_DMA_TO_DEVICE);
    if(status != XST_SUCCESS){
        	xil_printf("Error FAILED TO TRANSFER A\n\r");
        	return XST_FAILURE;
        }
    status = XAxiDma_SimpleTransfer(&AxiDmaB,(unsigned)B,dma_size,XAXIDMA_DMA_TO_DEVICE);
	if(status != XST_SUCCESS){
			xil_printf("Error FAILED TO TRANSFER B\n\r");
			return XST_FAILURE;
		}

    //wait for DMA transactions to finish
     /* while((XAxiDma_Busy(&AxiDmaA,XAXIDMA_DEVICE_TO_DMA)) ||
    		  (XAxiDma_Busy(&AxiDmaA,XAXIDMA_DMA_TO_DEVICE)) ||
    		  (XAxiDma_Busy(&AxiDmaB,XAXIDMA_DEVICE_TO_DMA)) ||
			  (XAxiDma_Busy(&AxiDmaB,XAXIDMA_DMA_TO_DEVICE)))
    	  xil_printf("transferring data to/from core\r\n");*/
     while(!ResultExample) xil_printf("Waiting for core to finish\n\r");
     result_hw = XDistance_squared_GetSum(&example);

     //call the software version of the function
     result_sw = distance_squared_sw(A,B);
     xil_printf("Comparing results from the sw and hw\n\r");
     xil_printf("Hardware: %f\r\nSoftware: %f\r\n", result_hw, result_sw);

    cleanup_platform();

    return 0;
}

NVCC=/usr/local/cuda/bin/nvcc
NVCC_OPT=-std=c++11

all:
	$(NVCC) $(NVCC_OPT) ga.cu -o ga

ga:
	$(NVCC) $(NVCC_OPT) ga.cu -o ga

clean:
	rm -f ga

install:



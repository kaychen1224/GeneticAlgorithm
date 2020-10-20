// C++ program to create target string, starting from 
// random string using Genetic Algorithm 

#include <bits/stdc++.h> 
#include <chrono>

using namespace std; 

// Number of individuals in each generation 
#define POPULATION_SIZE 100 

// Valid Genes 
const string GENES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890, .-;:_!\"#%&/()=?@${[]}"; 

// Target string to be generated 
const string TARGET = "I love GeeksforGeeksI love GeeksforGeeksI love GeeksforGeeks"; 

// Function to generate random numbers in given range 
int random_num(int start, int end) 
{ 
	int range = (end-start)+1; 
	int random_int = start+(rand()%range); 
	return random_int; 
} 

// Create random genes for mutation 
char mutated_genes() 
{ 
	int len = GENES.size(); 
	int r = random_num(0, len-1); 
	return GENES[r]; 
} 

// create chromosome or string of genes 
string create_gnome() 
{ 
	int len = TARGET.size(); 
	string gnome = ""; 
	for(int i = 0;i<len;i++) 
		gnome += mutated_genes(); 
	return gnome; 
} 

// Class representing individual in population 
class Individual 
{ 
public: 
	string chromosome; 
	int fitness; 
	Individual(string chromosome); 
	Individual mate(Individual parent2); 
	int cal_fitness(); 
}; 

Individual::Individual(string chromosome) 
{ 
	this->chromosome = chromosome; 
	fitness = cal_fitness(); 
}; 

// Perform mating and produce new offspring 
Individual Individual::mate(Individual par2) 
{ 
	// chromosome for offspring 
	string child_chromosome = ""; 

	int len = chromosome.size(); 
	for(int i = 0;i<len;i++) 
	{ 
		// random probability 
		float p = random_num(0, 100)/100; 

		// if prob is less than 0.45, insert gene 
		// from parent 1 
		if(p < 0.45) 
			child_chromosome += chromosome[i]; 

		// if prob is between 0.45 and 0.90, insert 
		// gene from parent 2 
		else if(p < 0.90) 
			child_chromosome += par2.chromosome[i]; 

		// otherwise insert random gene(mutate), 
		// for maintaining diversity 
		else
			child_chromosome += mutated_genes(); 
	} 

	// create new Individual(offspring) using 
	// generated chromosome for offspring 
	return Individual(child_chromosome); 
}; 


// Calculate fittness score, it is the number of 
// characters in string which differ from target 
// string. 
int Individual::cal_fitness() 
{ 
	int len = TARGET.size(); 
	int fitness = 0; 
	for(int i = 0;i<len;i++) 
	{ 
		if(chromosome[i] != TARGET[i]) 
			fitness++; 
	} 
	return fitness;	 
}; 

// Overloading < operator 
bool operator<(const Individual &ind1, const Individual &ind2) 
{ 
	return ind1.fitness < ind2.fitness; 
} 

__global__ void gpu_mate(const char* parent1, const char* parent2, char* offspring, float* probability, char* mutated) {
    int i = threadIdx.x;
	//printf("index:%d, %f, %c\n", i, probability[i], mutated[i]);

	if(probability[i] < 0.45)
		offspring[i] = parent1[i];
	else if(probability[i] < 0.9)
		offspring[i] = parent2[i];
	else
		offspring[i] = mutated[i];
}


string convertToString(char* a, int size) 
{ 
    int i; 
    string s = ""; 
    for (i = 0; i < size; i++) { 
        s = s + a[i]; 
    } 
    return s; 
} 

// Driver code 
int main(int argc, char **argv) 
{ 	
	int gpu = 0;
	if(argv[1] != NULL && (strcmp(argv[1],"gpu") == 0))
		gpu = 1;

	srand((unsigned)(time(0))); 

	// current generation 
	int generation = 0; 

	vector<Individual> population; 
	bool found = false; 

	// create initial population 
	for(int i = 0;i<POPULATION_SIZE;i++) 
	{ 
		string gnome = create_gnome(); 
		population.push_back(Individual(gnome)); 
	} 

	auto start = std::chrono::system_clock::now();

	char* gpu_parent1, *gpu_parent2, *gpu_offspring, *gpu_mutated;
	float* gpu_probability;

	if(gpu)
	{
		// Allocate device memory 
		cudaMalloc((void**)&gpu_parent1, sizeof(char) * TARGET.size());
		cudaMalloc((void**)&gpu_parent2, sizeof(char) * TARGET.size());
		cudaMalloc((void**)&gpu_offspring, sizeof(char) * TARGET.size());
		cudaMalloc((void**)&gpu_probability, sizeof(float) * TARGET.size());
		cudaMalloc((void**)&gpu_mutated, sizeof(char) * TARGET.size());
	}

	while(! found) 
	{ 

		// sort the population in increasing order of fitness score 
		sort(population.begin(), population.end()); 

		// if the individual having lowest fitness score ie. 
		// 0 then we know that we have reached to the target 
		// and break the loop 
		if(population[0].fitness <= 0) 
		{ 
			found = true; 
			break; 
		} 

		// Otherwise generate new offsprings for new generation 
		vector<Individual> new_generation; 

		// Perform Elitism, that mean 10% of fittest population 
		// goes to the next generation 
		int s = (10*POPULATION_SIZE)/100; 
		for(int i = 0;i<s;i++) 
			new_generation.push_back(population[i]); 

		// From 50% of fittest population, Individuals 
		// will mate to produce offspring 
		s = (90*POPULATION_SIZE)/100; 

		for(int i = 0;i<s;i++) 
		{ 
			int len = population.size(); 
			int r = random_num(0, 50); 
			Individual parent1 = population[r]; 
			r = random_num(0, 50); 
			Individual parent2 = population[r]; 

			// using gpu
			if(gpu)
			{
				char offspring[TARGET.size()]={0};
				float probability[TARGET.size()]={0.0};
				char mutated[TARGET.size()] = {0};
	
				for(int i=0;i<TARGET.size();i++)
				{
					probability[i] = (float)random_num(0,100)/100;
					mutated[i] = GENES[random_num(0,GENES.size())];
					//cout<<"probability[i]:"<<probability[i]<<endl;
					//cout<<"mutated[i]:"<<mutated[i]<<endl;
				}

				// Transfer data from host to device memory
				cudaMemcpy(gpu_parent1, parent1.chromosome.c_str(), sizeof(char) * TARGET.size(), cudaMemcpyHostToDevice);
				cudaMemcpy(gpu_parent2, parent2.chromosome.c_str(), sizeof(char) * TARGET.size(), cudaMemcpyHostToDevice);
				cudaMemcpy(gpu_mutated, mutated, sizeof(char) * TARGET.size(), cudaMemcpyHostToDevice);
				cudaMemcpy(gpu_probability, probability, sizeof(float) * TARGET.size(), cudaMemcpyHostToDevice);

				gpu_mate<<<1,TARGET.size()>>>(gpu_parent1, gpu_parent2, gpu_offspring, gpu_probability, gpu_mutated);

				// Transfer data back to host memory
				cudaMemcpy(offspring, gpu_offspring, sizeof(char) * TARGET.size(), cudaMemcpyDeviceToHost);
				new_generation.push_back(convertToString(offspring, TARGET.size())); 
			}
			else
			{
				Individual offspring = parent1.mate(parent2); 
				new_generation.push_back(offspring); 
			}
			// end
		} 
		population = new_generation; 
		cout<< "Generation: " << generation << "\t"; 
		cout<< "String: "<< population[0].chromosome <<"\t"; 
		cout<< "Fitness: "<< population[0].fitness << "\n"; 

		generation++; 
	} 
    auto end = chrono::system_clock::now();
    chrono::duration<double> elapsed_seconds = end-start;
    time_t end_time = chrono::system_clock::to_time_t(end);
    cout << "finished computation at " << ctime(&end_time)
              << "elapsed time: " << elapsed_seconds.count() << "s\n";

    float cost_per_generation = elapsed_seconds.count()/generation;
    cout<<"cost_per_generation:"<<cost_per_generation<<endl;

	cout<< "Generation: " << generation << "\t"; 
	cout<< "String: "<< population[0].chromosome <<"\t"; 
	cout<< "Fitness: "<< population[0].fitness << "\n"; 

	if(gpu)
	{
		// Deallocate device memory
		cudaFree(gpu_parent1);
		cudaFree(gpu_parent2);
		cudaFree(gpu_probability);
		cudaFree(gpu_offspring);
		cudaFree(gpu_mutated);
	}
} 

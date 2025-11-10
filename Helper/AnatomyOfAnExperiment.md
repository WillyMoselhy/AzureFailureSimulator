Experiment
    Step
        Branch
            Action (Fault)
                * Fault Type (VM Shutdown)
                  * Parameters (Duration / abrupt)
                * Target (Resource Id / Resource Graph KQL)
            Action (Delay)
                * Time in minutes to wait
        Branch (2)
    Step (2)


Steps run in sequence
Branches run in parallel
Actions run in sequence


for AKS: [Great Blog Post - See AZ experiment](https://www.jannemattila.com/azure/2024/08/26/chaos-studio-and-aks.html)
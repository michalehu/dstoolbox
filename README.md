# DSToolbox

DSToolbox is a Matlab toolbox for analyzing and modelling of unsteady fluid dynamics experiments.

## Installation

Clone the repository in the folder of choice on your computer. The src folder contains the source code and the script folder contains a bunch of script and example that make use of the toolbox functionalities.

## Organizaton 

The repository consists in the source code of the toolbox, in the src folder, and some scripts, that make use of the toolbox to produce valuable results, in the scripts fodler. 

The src folder contains three subdirectories: the common folder for class definitions that are useful in any dynamic stall model, the model folder for functions that are a specific model implmentation and the lib folder, which is a library of useful functions that are also common to all models.

## Usage

The repository consists in a collection of objects, such as airfoils or typical motions, that can be created and on which functions can be applied. Scipts can then be written where objects are created, such as in the example below : 

```matlab
airfoil = Airfoil('naca0012',0.5) % creates an Airfoil object with name naca0012 and 0.5m chord length
```
or for another object type: 

```matlab
ramp = RampUpMotion('r',0.01,'V',0.5) % creates an ramp-up object with reduced pitch rate 0.01 and incoming flow velocity 0.5m/s.
```

## License
[MIT](https://choosealicense.com/licenses/mit/)

# DSToolbox

DSToolbox is a Matlab toolbox for analyzing and modelling of unsteady fluid dynamics experiments.

## Installation

Clone the repository in the folder of choice on your computer, for example `Documents/MATLAB`. Open a Terminal window and type:

```bash
cd Documents/MATLAB
git clone git@github.com:lucasschn/dstoolbox
```
You can now make sure that you have a new folder called `dstoolbox` at the specified location. 

## Organization 

The `src` folder contains the source code and the `script` folder contains scripts and examples that make use of the toolbox functionalities. The `src`folder is further divided in three subfolders: 
- `common` contains the classes definitions for the core-objects of the toolbox, e.g. Airfoil, AirfoilMotion, or SteadyCurv that are used independently of the model. 
- `lib` contains a library of useful functions, not classes, also common to all models.
- `model` contains functions that are model-specific, e.g. only used for Sheng and Expfit models


## Usage

The repository consists in a collection of objects, such as airfoils or typical motions, that can be created and on which functions can be applied. Scripts can then be written where these objects are created, such as in the example below: 

```matlab
airfoil = Airfoil('naca0012',0.5) % creates an Airfoil object with name naca0012 and 0.5m chord length
airfoil.steady = SteadyCurve(alpha,CN,13) % creates a SteadyCurve object
```
The created steady curve is assigned as the steady/static curve to the airfoil, with angle of attack alpha, normal coefficient CN, and static stall angle 13°. Different methods apply to steady curves, for additional computations or for plots. 

```matlab
airfoil.steady.plotCN() % plots the normal coefficient as a function of the AoA
airfoil.steady.fitKirchhoff() % fits a Kirchhoff curve to the static stall curve
```

An other object is needed to represent the dynamic stall experiment. It can be a ramp-up motion with constant pitch rate: 

```matlab
ramp = RampUpMotion('r',0.01,'V',0.5) % creates an ramp-up object with reduced pitch rate 0.01 and incoming flow velocity 0.5m/s.
```

a sinusoidal motion with constant frequency:
```matlab
pitching = PitchingMotion('alpha',alpha,'CN',CN,'k',red_freq) % creates a pitching motion object with angle of attack vector alpha, normal coefficient CN and reduced frequency red_freq.
```

or a general motion with custom angle of attack history:

```matlab
motion = AirfoilMotion('alpha',alpha,'CN',CN)
```
RampUpMotion and PitchingMotion both inherit from AirfoilMotion, meaning that all properties and methods of AirfoilMotion also apply to RampUpMotion and PitchingMotion. Howvever, RampUpMotion and PitchingMotion both individually have properties and methods that AirfoilMotion does not, such as the reduced pitch rate `r` and the reduced frequency `k` respectively. 

All three airfoil motions accept name-value pair arguments when constructed. This means that you can pass any `'name',value` pair as an argument when creating the object to automatically assign the value `value` to the property `name` to the object, as long as the property `name` exists for this object. 

Different methods can be applied to a newly created ramp object, such as `setCL()` for setting the experiment lift coefficient corresponding to this ramp manually. A convenient function `loadRamp(casenumber,filtered)` sets up the experimental data to the ramp automatically from the server data. 

```matlab
ramp = loadRamp(22,false);
ramp.setPitchRate(airfoil);
ramp.findExpOnset()
```
The convenient function `ramp=loadRamp(c,filtered)` runs the labbook, loads the data, zeroes the data correctly and filters it if `filtered`is true. It then isolates the part of interest of the experiment, namely the ramp itself and a bit after it, and returns a RamUpMotion object `ramp` with the experimental force fields filled. Here the number 22 defines the experimental case number `c` corresponding to the desired experiement. All case numbers are defined in the labbook (`labbook.m`in the repository). `setPitchrate(airfoil)`must be executed independently because it requires an airfoil object as an argument (in order to define the reduced pitch rate, the chord length is required). This will also set the convectime time vector, which allows `findExpOnset()` to be run. It is recommended to take the habbit to declare a ramp using this three methods before any usage.

### Apply a dynamic stall model to an experimental case

Once the airfoil motion has been set up correctly, the corresponding aerodynamic normal coefficients can be predicted using a dynamic stall model. All dynamic stall models are methods that apply to motion objects. The general syntax for models is as follows: 

```matlab
ramp.BeddoesLeishman(airfoil,Tp,Tf,Tv,Tvl,'mode') % computes the aerodynamic loading experienced by an airfoil object describing the motion described by ramp according to Leishman-Beddoes model
```

The time constants Tp, Tf, Tv, and Tvl are necessary input arguments to Beddoes-Leishman model. Depending on the selected model the number of time constants can vary from 3 to 4. The 'mode' argument can be either 'experimental' or 'analytical' depending if the user wants numerical or analytical derivatives to be used. Alternatively, Sheng's model can be run on the same experimental data with the command:

```matlab
ramp.BLSheng(obj,airfoil,Tf,Tv,Tvl,alphamode) % computes the aerodynamic load according to Sheng's version of LB model
```

In Sheng's model, there is no necessity to provide the `Tp`constant, because the first delay due to airfoil unsteadiness is represented by the constant `Talpha`, which is determined based on experimental data. However, the prerequisite is that that constant has been already determined by running the script `ShengCriterion2019.m`. That one uses Sabrina's 2019 data. For Sabrina's 2018 data, see `ShengCriterion2018.m`.

```matlab
ramp.BLSheng(obj,airfoil,Tf,Tv,Tvl,alphamode) % computes the aerodynamic load according to Sheng's version of LB model
```

You can verify if the necessary script has been run or not by checking for the presence of a `linfit_flatplate.mat` matfile in your repository (in case you are considering the flat plate airfoil).  

### Test files

A collection of scripts, such as `testLB.m` or `testSheng.m` contain all the necessary code for creating a ramp object from experimental data and apply one of the available dynamic stall models, depending on the test script. In `testLB.m`, the lines corresponding to the experiment number, associated with a certain pitch rate, and the time constants used in the call for BeddoesLeishman() method can be changed: 

```matlab
c = 71; % change this number to select the desired experiment (see labbook)

ramp.BeddoesLeishman(airfoil,3,3,1,1,'experimental') % change the four numbers corresponding to Tp, Tf, Tv and Tvl respectively
```

### Parameter sweep

Part of this project is related to the analysis of the LB-prediction when the time constants are choosed randomly amongst a predefined population, with a large amount of samples. The script `paramsweep.m` runs the LB model using a user-defined number of samples among the user-defined range of Tp, Tf, Tv and Tvl. The script `plotSweepResults.m` allows for plotting the results of that parameter sweep using three different functions. 

* `plotOneRate(res,rate,varx,vary,color_var)` creates a scatter plot for the result mat-file loaded in the variable `res`, only for the experiments with pitch rate equal to `rate`. The x- and y-axis are defined by the variables `varx`and `vary`. The optional variable `color_var` allows for coloring the points on the scatter plot according to a third variable. 
* `plotAllRates(res,varx,vary)` creates a scatter plot for `res`, with x- and y-axis defined by the variables `varx`and `vary`. here no disction of pitch rate is made and all results are plotted.
* `plotHistogram(res,varx,vary,threshold)` creates histograms for the result mat-file loaded in `res` with x-axis `varx`. The first one shows the distribution of all samples along the variable `varx` (in blue). The second one shows the distribution of samples meeting the criterion |vary|<threshold along the variable `varx` (in red). The two first ones are superimposed on the same axes. A third one in a new figure is then created showing the ratio between the samples meeting the criterion and the total number of samples for each bin of `varx`.

## App

Before using the app, you have to run the script `setPaths.m`on your machine with the correct path to the folder where you want the produced figures to be saved.

## Troubleshooting

When running a file always make sure that your current folder is the folder containing the file. For example, many scripts won't execute correctly if your current folder is not `dstoolbox/scripts`.


If you see the error message

```
Matlab couldn't read the experimental data. Are you sure you are connected to the server?
```

Make sure you are connected to the raw server. Otherwise, open labbook.m and make sure the path to the smartH folder is correctly set. 

If Matlab stops responding when trying to load data from the server, first wait for at least 1min. The loading process of files up to 2GB has been observed to take around 30s on some configurations. 

Then, check your firewall preferences. To make sure you can properly read a file from the server, browse to the file and try to manually open it by clicking on it. 

On Windows machines, a permanent solution is to add the files and the raw servers to the list of sites considered as part of the local intranet. To do this, follow the instruction [there](https://winraedorpers.com/fr/windows/1165-windows-fix-8220we-can8217t-verify-who-created-this-file8221-error.html)

Please report any issue you may find using [Github's tool for issue reporting] (https://github.com/lucasschn/dstoolbox/issues)

## License
[MIT](https://choosealicense.com/licenses/mit/)

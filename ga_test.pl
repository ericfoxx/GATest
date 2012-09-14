#!perl

use warnings;
use strict;
use Getopt::Long;           # support options+arguments
use Pod::Usage;             # gimme this program's manpage!
use POSIX qw(ceil floor);   # for ceiling, floor math functions

#GA Test: testing a quick and dirty genetic algorithm
# wherein a genetic algorithm converges upon arbitrary integer user input

#Getopt options
#meta-options
my $opt_help  = '';          # help option          (false)
my $opt_man   = '';          # manpage option       (false)
#program-specific options
my $opt_verbose = 0;         # verbosity
my $opt_test  = '';          # testing mode         (false)
my $opt_interact = '';       # interactive mode     (false)
my $opt_input = 
   int(rand(500000)+500000); # integer input
my $opt_gens  = 20;          # number of generations
my $opt_size  = 40;          # number of individuals in the population  MUST BE EVEN
my $opt_fit   =  2;          # fitness function to use
my $opt_analy =  0;          # analytics

GetOptions (
    'help'          =>  \$opt_help     ,
    'man'           =>  \$opt_man      ,
    'verbose:i'     =>  \$opt_verbose  ,
    'test'          =>  \$opt_test     ,
    'interactive'   =>  \$opt_interact ,
    'input:i'       =>  \$opt_input    ,
    'gens:i'        =>  \$opt_gens     ,
    'size|indiv:i'  =>  \$opt_size     ,
    'fit:i'         =>  \$opt_fit      ,
    'analytics:i'   =>  \$opt_analy
) or pod2usage(-verbose => 1) && exit; #prints SYNOPSIS & ARGUMENTS and exits if error processing args

#input errors
pod2usage(-message => "Input must be greater than 0.", -verbose => 1) && exit if ($opt_input < 0);
pod2usage(-message => "Generations must be more than 0.", -verbose => 1) && exit if ($opt_gens < 1);
pod2usage(-message => "Size of pop. must be a positive even number.", -verbose => 1) && exit if ($opt_size < 2 || $opt_size % 2);
pod2usage(-message => "Incorrect fitness type.", -verbose => 1) && exit if ($opt_fit !~ /^[12]$/); #CHANGE if added fitness types
pod2usage(-message => "Analytics out of range.", -verbose => 1) && exit if ($opt_analy !~ /^[012]$/); #CHANGE if added analytics types

#documentation and exit
$opt_help = 0 if $opt_man;
pod2usage(-verbose => 1, -exit=>0) if $opt_help;
pod2usage(-verbose => 2, -exit=>0) if $opt_man;

#program-specific variables
my ($input,
    %analytics, $temp, @tArr,
    $numGens, $currGen,
    @pop, @newPop,
    @fittest, $fitType,
    $popSize, $popIter,
    $r1, $r2, @tourn1, @tourn2,
    $parent1, $parent2, $kid1, $kid2,
    $mutChoice, $mutRate,
    $wait
);

#input checking stubs
$input = 500000;
$numGens = 20;
$popSize = 40;
$fitType = 2;
$temp = 0;
%analytics = ("level"   => 0,
              "mean"    => 0,
              "median"  => 0,
              "sd"      => 0,
              "fittest" => 0,
              "fitF"    => 0,
              "fitN"    => 0,
              "least"   => 0,
              "leastF"  => 0,
              "leastN"  => 0   );

#interactive mode and batch mode initialization of variables
if ($opt_interact) {
    print "ga_test: Interactive mode\n" if ($opt_verbose >= 1);
    #interactive mode
    print "Welcome to the Quick and Dirty GA program.\n"
        . "Enter values for the following parameters or press enter to accept default.\n";
    do{
        if ($input < 1){
            print "Please input a positive integer!\n";
        }
        print "Input a large positive integer:\n[random] ";
        chomp($input = <>);
        $input = int(rand(500000)+500000) unless ($input);
    } while ($input < 1);
    do{
        if ($numGens < 1){
            print "Please input a positive integer!\n";
        }
        print "Input the number of generations to run:\n[20] ";
        chomp($numGens = <>);
        $numGens = 20 unless ($numGens);
    }while ($numGens < 1);
    do {
        if ($popSize % 2) {
            print "Please input a positive, even integer!\n";
        }
        print "Input the number of individuals in the population:\n[40] ";
        chomp($popSize = <>);
        $popSize = 40 unless ($popSize);
    } while (($popSize < 2) || ($popSize % 2));
    do{
        #CHANGE VALUES if added fitness types
        if ($fitType !~ /^[12]$/){
            print "Incorrect fitness type.\n";
        }
        print "Fitness: choose the fitness function to use:\n"
            . "1. Simple distance fitness\n"
            . "2. Exponential piecewise fitness\n[2] ";
        chomp($fitType = <>);
        $fitType = 2 unless ($fitType);
    }while ($fitType !~ /^[12]$/);
    do{
        #CHANGE VALUES if added analytics types
        if ($analytics{"level"} !~ /^[012]$/){
            print "Incorrect analytics type.\n";
        }
        print "Choose your level of analytics:\n"
            . "0. No analytics\n"
            . "1. Simple: mean, standard deviation,"
                  . " and fittest member of population\n"
            . "2. Advanced: simple with median and least"
                  . " fit member of population\n[0] ";
        chomp($analytics{"level"} = <>);
        $analytics{"level"} = 0 unless ($analytics{"level"});
    }while ($analytics{"level"} !~ /^[012]$/);
#    print "Mutation: choose the mutation rate (recommmended: 0.01)\n";
#    chomp($mutRate = <>);

    print "Running...\n";
} else {
    #batch mode
    $input              = $opt_input;
    $numGens            = $opt_gens;
    $popSize            = $opt_size;
    $fitType            = $opt_fit;
    $analytics{"level"} = $opt_analy;
    if ($opt_verbose >= 1){
        print "ga_test: Batch mode\n"
    }
}
#batch or interactive variable listing for verbosity 1 or higher
if ($opt_verbose >= 1){
    print "ga_test: program variables\n";
    print "Input\t\t$input\n"
        . "Generations\t$numGens\n"
        . "Population\t$popSize\nFitness type:\t";
    if ($fitType == 1) {
        print "distance\n";
    } elsif ($fitType == 2) {
        print "exponential\n";
    }
    print "Analytics:\t";
    if ($analytics{"level"} == 0) {
        print "none\n";
    } elsif ($analytics{"level"} == 1){
        print "simple\n";
    } elsif ($analytics{"level"} == 2){
        print "advanced\n";
    }
}

#initalization

#pop is a 2-d array containing randomly initialized individuals and their fitness
for ($popIter = 0; $popIter < $popSize; $popIter++){
    do {
        $pop[$popIter][0] = int(rand( 2 * $input));
    } while ($pop[$popIter][0] == $input); #No easy wins!
}

if ($opt_verbose >= 2){
    print "ga_test: Immediately after initialization, population is:\n";
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        print $popIter . ":\t" . $pop[$popIter][0] . "\n";
    }
}

#run main generational loop only once if testing
$numGens = 1 if ($opt_test);
$mutRate = 0.01;

#main generational loop
for ($currGen = 0; $currGen < $numGens; $currGen++){
    #measure fitness, perform selection, reproduce
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        #measure fitness
        if ($fitType == 1){
            #Simple distance-based fitness function
            $pop[$popIter][1] = abs($input - $pop[$popIter][0]); #very simple distance measure
            #Determine fittest
            if ($popIter == 0){
                @fittest = ($pop[$popIter][0], $pop[$popIter][1], $popIter);
            } elsif ($fittest[1] > $pop[$popIter][1]){
                @fittest = ($pop[$popIter][0], $pop[$popIter][1], $popIter);
            }
        } elsif ($fitType == 2){
            #Exponential piecewise defined fitness function, centered at $input
            #Between 0 and input:
            #                    -$input
            # fitness = ----------------------------
            #            -1.001*$input + individual
            #Between input and 2*input
            #                    $input
            # fitness = ---------------------------
            #            individual - .999*$input
            if ($pop[$popIter][0] <= $input) {
                $pop[$popIter][1] = ((0-$input)/(0-(1.001*$input)+$pop[$popIter][0]));
            } elsif ($pop[$popIter][0] > $input) {
                $pop[$popIter][1] = ($input/($pop[$popIter][0]-(0.999*$input)));
            }
            #Determine fittest
            if ($popIter == 0){
                @fittest = ($pop[$popIter][0], $pop[$popIter][1], $popIter);
            } elsif ($fittest[1] < $pop[$popIter][1]){
                @fittest = ($pop[$popIter][0], $pop[$popIter][1], $popIter);
            }
        } #place next fitType logic here
    }
    #verbose or test output of current generation
    if ($opt_verbose >= 1 || $opt_test){
        print "ga_test: Inside generation loop, generation $currGen\nAfter fitness loop, pop is:\n";
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            print $popIter . ":\t" . $pop[$popIter][0] . "\t";
            printf ('%.4f', $pop[$popIter][1]);
            print "\tFITTEST!" if ($fittest[2] == $popIter);
            print "\n";
        }
    }
    #Analytics:
    # Simple analytics: mean, standard deviation, and fittest member of population
    if ($analytics{"level"} >= 1){
        print "Analytics: generation $currGen\n";
        print "mean\t\tsd\t\tfittest in form individual:value(fitness)\n";
        #mean
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            $analytics{"mean"} += $pop[$popIter][0];
        }
        $analytics{"mean"} = $analytics{"mean"} / $popSize;
        #standard deviation
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            $temp += ($analytics{"mean"}-$pop[$popIter][0])**2;
        }
        $analytics{"sd"} = sqrt($temp / ($popSize-1));
        #fittest member of population and its fitness
        $analytics{"fittest"} = $fittest[0];
        $analytics{"fitF"} = $fittest[1];
        $analytics{"fitN"} = $fittest[2];
        printf "%.2f\t%.2f\t%d:%d(%.1f)\n", $analytics{"mean"}, $analytics{"sd"},
                $analytics{"fitN"}, $analytics{"fittest"}, $analytics{"fitF"};
    }
    # Advanced analytics: simple with median and least fit member of population
    if ($analytics{"level"} >= 2){
        print "median\t\tleast fit\n";
        #median
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            $tArr[$popIter] = $pop[$popIter][0];
        }
        @tArr = sort(@tArr); #copy of population
        $analytics{"median"} = ($tArr[($popSize/2)-1] + $tArr[$popSize/2])/2;
        #least fit member of population and its fitness
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            if ($popIter == 0){
                $analytics{"least"} = $pop[$popIter][0];
                $analytics{"leastF"} = $pop[$popIter][1];
                $analytics{"leastN"} = $popIter;
            } elsif ($analytics{"leastF"} > $pop[$popIter][1]){
                $analytics{"least"} = $pop[$popIter][0];
                $analytics{"leastF"} = $pop[$popIter][1];
                $analytics{"leastN"} = $popIter;
            }
        }
        printf "%.1f\t%d:%d(%.1f)\n", $analytics{"median"}, $analytics{"leastN"},
                $analytics{"least"}, $analytics{"leastF"};
    }
    #test for perfect fitness of top individual, for termination
    if ($fittest[0] == $input){
            last;
    }
    #Selection
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        #simple 2-way tournament selection
        #remember to maintain stochasticity by allowing selection of some less fit members
        $r1 = int(rand($popSize));
        $r2 = int(rand($popSize));
        @tourn1 = ($pop[$r1][0], $pop[$r1][1]);
        @tourn2 = ($pop[$r2][0], $pop[$r2][1]);
        if ($tourn1[1] >= $tourn2[1]) {
            $newPop[$popIter] = $tourn1[0];
        } else {
            $newPop[$popIter] = $tourn2[0];
        }
        #test output
        if ($opt_test){
            print "ga_test: Inside selection loop, tournament between $r1:" . $tourn1[0] . " (fit: ";
            printf('%.2f', $tourn1[1]);
            print ") and $r2:" . $tourn2[0] . " (fit: ";
            printf('%.2f', $tourn2[1]);
            print ")\n";
            #select(undef, undef, undef, 0.250);
        }
    }
    #post-selection verbose or test output of new generation before crossover
    if ($opt_verbose >= 2 || $opt_test){
        print "ga_test: Inside generation loop, generation $currGen\nAfter selection loop, NEW pop is:\n";
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            print $popIter . ":\t" . $newPop[$popIter] . "\n";
        }
    }
    #Reproduction (non-crossover, average-distance)
    for ($popIter = 0; $popIter < $popSize; $popIter+= 2){
        #Each set of parents must have 2 kids. Parents are paired from existing data
        $parent1 = $newPop[$popIter];
        $parent2 = $newPop[$popIter+1];
        #kid 1 is avg of two parents, replaces parent 1 after pair is computed
        $kid1 = int(($parent1+$parent2)/2);
        #kid 2 is only a little bit away from parent 1, in the direction of parent 2
        $kid2 = int($parent1+($parent2-$parent1)*.1);
        #both kids replace parents at the same time, loop completes.
        $newPop[$popIter]   = $kid1;
        $newPop[$popIter+1] = $kid2;
        #test output
        if ($opt_test){
            print "ga_test: Inside reproduction loop, children of $popIter:" . $parent1
                . " and " . ($popIter+1) . ":" . $parent2 . " are " . $kid1 . " and "
                . $kid2 . "\n";
            #select(undef, undef, undef, 0.250);
        }
    }
    #post-reproduction verbose or test output before mutation
    if ($opt_verbose >= 2 || $opt_test){
        print "ga_test: Inside generation loop, generation $currGen\nAfter reproduction loop, NEW pop is:\n";
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            print $popIter . ":\t" . $newPop[$popIter] . "\n";
        }
    }
    #Mutation
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        #Randomly select individuals and mutate
        next if rand > $mutRate;
        $mutChoice = int(rand(2));
        if ($mutChoice == 0){
            if ($opt_test){
                print "ga_test: Inside mutation loop, $popIter mutated from " . $newPop[$popIter];
            }
            $newPop[$popIter] = ceil($newPop[$popIter]*1.001); #increase by .1%, ceiling
            if ($opt_test){
                print " to " . $newPop[$popIter] . "\n";
            }
        } elsif ($mutChoice == 1){
            if ($opt_test){
                print "ga_test: Inside mutation loop, $popIter mutated from " . $newPop[$popIter];
            }
            $newPop[$popIter] = floor($newPop[$popIter]*0.999); #decrease by .1%, floor
            if ($opt_test){
                print " to " . $newPop[$popIter] . "\n";
            }
        }
    }
    #post-reproduction verbose or test output before mutation
    if ($opt_verbose >= 2 || $opt_test){
        print "ga_test: Inside generation loop, generation $currGen\nAfter mutation loop, NEW pop is:\n";
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            print $popIter . ":\t" . $newPop[$popIter] . "\n";
        }
    }
    #assignment of new population to the population array
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        ($pop[$popIter][0], $pop[$popIter][1]) = ($newPop[$popIter], 0);
    }
    #post-assignment test output before end of this generation
    if ($opt_test){
        print "ga_test: Inside generation loop, generation $currGen\nAfter assignment loop, pop is:\n";
        for ($popIter = 0; $popIter < $popSize; $popIter++){
            print $popIter . ":\t" . $newPop[$popIter] . "\n";
        }
    }
    #End of this generation.
    if ($opt_verbose >= 1){
        #wait for user
        $wait = <>;
    }
}

#Termination
if ($fittest[0] == $input){
    print "The input ($input) was converged upon in generation $currGen:\n";
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        print $popIter . ":\t" . $pop[$popIter][0] . "\t";
        print "Converged!" if ($pop[$popIter][0] == $input);
        #printf ('%.4f', $pop[$popIter][1]);
        #print "\tConverged!" if ($fittest[2] == $popIter);
        print "\n";
    }
    exit(1);
} else {
    print "The input ($input) was NOT converged upon by generation $currGen:\n";
    for ($popIter = 0; $popIter < $popSize; $popIter++){
        print $popIter . ":\t" . $pop[$popIter][0] . "\t";
        #printf ('%.4f', $pop[$popIter][1]);
        #print "\tFittest!" if ($fittest[2] == $popIter);
        print "\n";
    }
    exit(0);
}

__END__

=head1 NAME

ga_test.pl

=head1 DESCRIPTION

A genetic algorithm converges upon a user-supplied number.

Switches can be in long or short form.
eg:
  ga_test.pl --man
  ga_test.pl -m

=head1 SYNOPSIS

ga_test.pl [--help | man] [--verbose int] [--test] [--interact]
           [--input int] [--gens int] [--size int] [--fit int]
           [--analytics int]

=head1 OPTIONS

=over 8

=item B<--help>

Print Options and Arguments instead of executing.

=item B<--man>

Print complete man page instead of executing.

=item B<--verbose>

Determines the level of verbosity of the output. Default: 0.
Try level 2 for lots of scrolling.

=item B<--test>

Only create the population and runs for one generation with
very verbose output.

=item B<--interact>

Run the program in interactive mode, prompting for settings.

=item B<--input>

An optional integer. The target number for the genetic
algorithm. Random in the range of [500000,1000000] by default.

=item B<--gens>

An optional integer. The number of generations to run.
Default: 20.

=item B<--size>

An optional integer. The population size: the number of
individuals in every generation. MUST BE EVEN! Default: 40.

=item B<--fit>

An optional integer. The method of fitness evaluation.
Option 1: simple distance fitness.
Option 2: advanced exponential fitness. Default.

=item B<--analytics>

An optional integer. The level of analytics output.
Option 1: mean, standard deviation, and fittest individual
Option 2: median, least fit individual

=back

=head1 AUTHOR

Jesse Smith, MS HCI - Georgia Tech, December 2009. Jesse enjoys long walks
through the parks of Atlanta with his lovely wife, Terri.

=head1 CREDITS

Thanks ybiC for writing the wonderful tutorial on GetOpt::Long and
Pod::Usage. (http://perlmonks.org/?node_id=155288)
Thanks O'Reilly for making such outstanding reference books. TMTOWTDI!
Program based on undergraduate research under Dr. Gerald Adkins

=head1 BUGS

Mean and sd might not be correct, though the code looks fine. Checking
with graphing.

=head1 TODO

Add graphing (perhaps saved in seperate file).
Modularity and encapsulation.
Translation into a perl module.
Idea for translation: options to 'step' or 'run' through the generations
Getters/setters: INPUT() would return, while INPUT(3896) would set

=head1 UPDATES

 11/11/2009 11:29:30 PM
  Alpha, but running. 50% done. Still have to finish base functionality:
  selection, reproduction, mutation, termination.
 11/12/2009 3:13:53 AM
  75% done. Still have to finish base functionality: reproduction, 
  mutation, termination. For next time: enforce popSize MUST be even!
 11/12/2009 6:03:55 PM
  85% done. Still have to finish base functionality: reproduction, 
  termination. Input correctness checking on cmd line input has been 
  included, as well as error messages in pod2usage when encountering input 
  errors on cmd line. Enforced popSize must be even (on CMD LINE ONLY)! 
  Still need it in interactive mode. Also need i-mode switch checking and 
  input correctness checking.
 11/12/2009 11:14:25 PM
  Base functionality complete. It converges upon the number within 20
  generations of 40 individuals! Next on the list: rigorous input checking
  and then meta-analysis!
 11/14/2009 8:14:46 PM
  Analytics 33% done. Needs printing. After that, graphs!
 11/16/2009 1:13:17 AM
  Analytics done, but I don't like the formatting. Edited the documentation.
  Graphs next!
=cut

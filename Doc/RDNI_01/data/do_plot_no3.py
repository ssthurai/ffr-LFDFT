import numpy as np
import matplotlib.pyplot as plt

FILEPLOT = '../images/atom_H.pdf'

from matplotlib import rc
rc('font',**{'family':'serif', 'size':16})
rc('text', usetex=True)

dat1 = np.loadtxt('atom_H_oct.dat')
dat2 = np.loadtxt('atom_H_LF.dat')

plt.clf()
plt.plot( dat1[:,0], dat1[:,1], marker='o', linewidth=2, label='OCTOPUS' )
plt.plot( dat2[:,0], dat2[:,1], marker='^', linewidth=2, label='LFDFT' )
plt.grid()
plt.legend(loc='upper left')
plt.xlabel('Grid spacing (bohr)')
plt.ylabel('Electronic energy (Ha)')
plt.savefig(FILEPLOT)

import os
os.system('pdfcrop ' + FILEPLOT + ' ' + FILEPLOT)

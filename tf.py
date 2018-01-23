#!/usr/bin/env python3

import os
import argparse

import tensorflow as tf
import learning.network as network
import learning.training as training
import learning.resample as resample


if __name__ == "__main__":

    # Parse our command line arguments
    command = argparse.ArgumentParser(description='Utility for training the Visual Mesh')

    subcommands = command.add_subparsers(dest='command')

    subcommands = {
        'train': subcommands.add_parser('train'),
        'resample': subcommands.add_parser('resample'),
    }

    for k, c in subcommands.items():
        # Which GPU to use and the network structure to use
        c.add_argument('-g', '--gpu', action='store', default=0)
        c.add_argument('-s', '--structure', action='store')
        c.add_argument('-t', '--type', action='store')
        c.add_argument('-l', '--size', action='store')

        # The input and output folders
        c.add_argument('input', action='store')

        # The output folders
        c.add_argument('output', action='store')

    subcommands['resample'].add_argument('-m', '--model', action='store')

    args = command.parse_args()

    # Tensorflow configuration
    config = tf.ConfigProto()
    config.allow_soft_placement = True
    config.graph_options.build_cost_model = 1
    config.gpu_options.allow_growth = True

    with tf.Session(config=config) as sess:

        # Work out the network structure from the arguments
        structure = [[int(v) for v in l.split('-')] for l in args.structure.split('_')]
        network_name = '_'.join(['-'.join([str(l) for l in g]) for g in structure])

        # Select our device to run operations on
        with tf.device('/device:GPU:{}'.format(args.gpu)):

            # Build our network
            net = network.build(structure)

            # Run the appropriate action
            if args.command == 'train':

                os.makedirs(os.path.join(args.output, '{}{}'.format(args.size, args.type), network_name), exist_ok=True)
                os.makedirs(os.path.join(args.output, '{}{}'.format(args.size, args.type), network_name, 'yaml_models'), exist_ok=True)

                training.train(sess,
                               net,
                               args.type,
                               args.size,
                               args.input,
                               os.path.join(args.output, '{}{}'.format(args.size, args.type), network_name))

            elif args.command == 'resample':
                resample.resample(sess,
                                  net,
                                  args.type,
                                  args.size,
                                  os.path.join(args.model, '{}{}'.format(args.size, args.type), network_name),
                                  args.input,
                                  args.output)

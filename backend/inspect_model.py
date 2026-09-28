import numpy as np
import tensorflow as tf
import os
import sys

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

model_path = 'assets/veriframe_model.tflite'
print('model exists:', os.path.exists(model_path), flush=True)
i = tf.lite.Interpreter(model_path=model_path)
i.allocate_tensors()
ind = i.get_input_details()[0]
outd = i.get_output_details()[0]
print('Input shape:', ind['shape'], 'dtype:', ind['dtype'], flush=True)
print('Output shape:', outd['shape'], 'dtype:', outd['dtype'], flush=True)

fake = np.zeros(ind['shape'], dtype=ind['dtype'])
i.set_tensor(ind['index'], fake)
i.invoke()
out = i.get_tensor(outd['index'])
print('Zeros output:', out, 'flat:', out.flatten(), flush=True)

fake.fill(255.0)
i.set_tensor(ind['index'], fake)
i.invoke()
out = i.get_tensor(outd['index'])
print('255 output:', out, 'flat:', out.flatten(), flush=True)

for seed in [42, 123, 999]:
    np.random.seed(seed)
    noise = np.random.randn(*ind['shape']).astype(ind['dtype']) * 0.1
    i.set_tensor(ind['index'], noise)
    i.invoke()
    out = i.get_tensor(outd['index'])
    print(f'Noise seed {seed}:', out.flatten(), flush=True)
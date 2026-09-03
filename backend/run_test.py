import numpy as np
import tensorflow as tf
import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
i = tf.lite.Interpreter(model_path='D:/Veriframe/Veriframe/assets/veriframe_model.tflite')
i.allocate_tensors()
ind = i.get_input_details()[0]
outd = i.get_output_details()[0]
fake = np.zeros(ind['shape'], dtype=ind['dtype'])
i.set_tensor(ind['index'], fake)
i.invoke()
out = i.get_tensor(outd['index'])[0][0]
print('SCORE_ZERO:', out)

fake.fill(255.0)
i.set_tensor(ind['index'], fake)
i.invoke()
out = i.get_tensor(outd['index'])[0][0]
print('SCORE_WHITE:', out)

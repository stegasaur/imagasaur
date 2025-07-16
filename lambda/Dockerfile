FROM public.ecr.aws/lambda/python:3.13

# Copy function code
COPY . ${LAMBDA_TASK_ROOT}

# Install dependencies
RUN pip install --upgrade pip setuptools wheel
RUN pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

CMD ["lambda_function.lambda_handler"]

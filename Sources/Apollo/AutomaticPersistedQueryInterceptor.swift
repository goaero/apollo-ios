import Foundation

public class AutomaticPersistedQueryInterceptor: ApolloInterceptor {
  
  public enum APQError: Error {
    case noParsedResponse
  }
  
  public func interceptAsync<ParsedValue: Parseable, Operation: GraphQLOperation>(
    chain: RequestChain,
    request: HTTPRequest<Operation>,
    response: HTTPResponse<ParsedValue>,
    completion: @escaping (Result<ParsedValue, Error>) -> Void) {
    
    guard
      let jsonRequest = request as? JSONRequest,
      jsonRequest.autoPersistQueries else {
        // Not a request that handles APQs, continue along
        chain.proceedAsync(request: request,
                           response: response,
                           completion: completion)
        return
    }
    
    guard let result = response.parsedResponse as? GraphQLResult<Operation.Data> else {
      // We can't handle this situation.
      chain.handleErrorAsync(APQError.noParsedResponse,
                             request: request,
                             response: response,
                             completion: completion)
      return
    }
    
    guard let errors = result.errors else {
      // No errors were returned so no retry is necessary, continue along.
      chain.proceedAsync(request: request,
                         response: response,
                         completion: completion)
      return
    }
    
    let errorMessages = errors.compactMap { $0.message }
    guard errorMessages.contains("PersistedQueryNotFound") else {
      // The errors were not APQ errors, continue along.
      chain.proceedAsync(request: request,
                         response: response,
                         completion: completion)
      return
    }
    
    // We need to retry this query with the full body.
    jsonRequest.isPersistedQueryRetry = true
    chain.retry(request: jsonRequest,
                completion: completion)
  }
}